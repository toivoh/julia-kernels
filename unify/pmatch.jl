
load("utils/req.jl")
req("utils/utils.jl")
req("unify/unify.jl")


function split_fdef(fdef::Expr)
    @expect (fdef.head == :function) || (fdef.head == :(=))
    @expect length(fdef.args) == 2
    signature, body = tuple(fdef.args...)
    @expect is_expr(signature, :call)
    @expect length(signature.args) >= 1
    (signature, body)
end
split_fdef(f::Any) = error("split_fdef: expected function definition, got\n$f")



type RuntimeValue <: Pattern{Any}
    name::Symbol
end

# -- recode_pattern -----------------------------------------------------------

type RPContext
    vars::Dict{Symbol,PVar}
    unmatchable::Bool # todo: use!

    RPContext() = new(Dict{Symbol,PVar}(), false)
end

getvar(c::RPContext, name::Symbol) = getvar(c, name, Any)
function getvar(c::RPContext, name::Symbol, T)
    if has(c.vars, name)
        var = c.vars[name]
        @expect isequal(pattype(var), T)
        return var
    else
        var = PVar(name, T)
        return c.vars[name] = var
    end
end

function recode_pattern(c::RPContext, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head == doublecolon
        @expect nargs==2
        return quoted_expr(getvar(c, args[1], args[2]))
    elseif contains([:call, :ref, :curly], head)
        if (head==:call) && (args[1]==:value)
            @expect nargs==2
            return quoted_expr(RuntimeValue(args[2]))
        else
            return expr(head, args[1], 
                        {recode_pattern(c,arg) for arg in ex.args[2:end]}...)
        end
    else
        return expr(head, {recode_pattern(c,arg) for arg in ex.args})
    end
end
recode_pattern(c::RPContext, sym::Symbol) = quoted_expr(getvar(c, sym))
recode_pattern(c::RPContext, ex) = ex # other terminals


# -- code_pmatch --------------------------------------------------------------

type PVarEntry
    name::Symbol
    isassigned::Bool
    PVarEntry(name::Symbol) = new(name, false)
end
type PMContext
    vars::Dict{PVar, PVarEntry}
    ret_nomatch
    code::Vector

    PMContext(ret_nomatch) = new(Dict{PVar, PVarEntry}(), ret_nomatch, {})
    PMContext() = PMContext(:false)
end

PMContext(rpc::RPContext, args...) = PMContext(rpc.vars, args...)
function PMContext(vars::Dict, args...)
    c = PMContext(args...)
    for (name::Symbol, p::PVar) in vars
        c.vars[p] = PVarEntry(name)
    end
    c
end

emit(c::PMContext, ex) = (push(c.code,ex); nothing)

function get_entry(c::PMContext, p::PVar)
    if !has(c.vars, p)
#        c.vars[p] = PVarEntry(gensym(string(p.name)))
#        c.vars[p] = PVarEntry(p.name)
        error("code_pmatch: undefined PVar p = ", p)
    end
    entry = c.vars[p]
end


function code_iffalse_ret(c::PMContext, pred)
    :(if !($pred)
        return ($c.ret_nomatch)
    end)
end

code_pmatch(c::PMContext, ::NonePattern,::Symbol) = error("code_pmatch: "*
                                                  "pattern never matches")
function code_pmatch(c::PMContext, p::PVar,xname::Symbol)
    entry = get_entry(c, p)
    if entry.isassigned
        emit(c, code_iffalse_ret(c, :( isequal(($entry.name),($xname))) ))
    else
        if !isuniversal(p.dom)
            emit(c, code_iffalse_ret(c, code_contains(p.dom,xname)))
        end
        emit(c, :(
            ($entry.name) = ($xname)
        ))
        entry.isassigned = true
    end
end
function code_pmatch(c::PMContext, p::RuntimeValue,xname::Symbol)
    emit(c, code_iffalse_ret(c, :( isequal(($p.name),($xname)) )))
end
function code_pmatch(c::PMContext, p,xname::Symbol)
    @assert isatom(p)
    emit(c, code_iffalse_ret(c, :( isequal(($quoted_expr(p)),($xname)) )))
end
function code_pmatch_list(T, c::PMContext, ps,xname::Symbol)
    np = length(ps)
    emit(c, code_iffalse_ret(c,  :(
        (isa(($xname),($quoted_expr(T))) && length($xname) == ($np))
    )))
    for k=1:np
        xname_k = gensym()
        emit(c, :(($xname_k) = ($xname)[$k]))
        code_pmatch(c, ps[k], xname_k)
    end
end
function code_pmatch(c::PMContext, ps::Tuple,xname::Symbol)
    code_pmatch_list(Tuple, c, ps,xname)
end
function code_pmatch(c::PMContext, ps::Vector,xname::Symbol)
    code_pmatch_list(Vector, c, ps,xname)
end


# -- @ifmatch -----------------------------------------------------------------

macro ifmatch_let(ex)
    code_ifmatch(ex)
end
function code_ifmatch_let(ex)
    @expect is_expr(ex, :let)
    body = ex.args[1]
    #matches = ex.args[2:end]
    @expect length(ex.args) == 2
    match = ex.args[2]

    @expect is_expr(match, :(=), 2)

    pattern, valex = match.args[1], match.args[2]
    code_ifmatch_let(pattern, valex, body)
end

function code_ifmatch_let(pattern, valex, body)
    valname = gensym("value")
    
    rpc = RPContext()
    pattern = recode_pattern(rpc, pattern)
    pattern = eval(pattern)

    pmc=PMContext(rpc)
    code_pmatch(pmc, pattern,valname)
    push(pmc.code, :true)
#    foreach(pprintln, pmc.code)

    varnames = {kv[2].name for kv in pmc.vars}
#    pmatch

    :(
        let ($valname)=($valex)
            local ($varnames)
            if let
                ($pmc.code...)
            end
                ($body)
                true
            else
                false
            end
        end
    )
end


# -- @patmethod ---------------------------------------------------------------

type PatternMethod
    arguments::Dict{Symbol,PVar}
    pattern
    body

    dispfun::Function
   
    PatternMethod(arguments, pattern, body) = new(arguments, pattern, body)
end

function create_pmethod_closure(m::PatternMethod)
    eval(code_pmethod_closure(m))
end
function code_pmethod_closure(m::PatternMethod)
    argsname = gensym("args")

    pmc=PMContext(m.arguments, :(false,nothing))
    code_pmatch(pmc, m.pattern,argsname)
    push(pmc.code, :(true, ($m.body)))

    :( (($argsname)...)->(begin
        ($pmc.code...)        
    end))
end

function patmethod(arguments::Dict{Symbol,PVar}, pattern, body)
    m = PatternMethod(arguments, pattern, body)
    m.dispfun = create_pmethod_closure(m)
    m
end


function code_patmethod(pattern_ex, body)
    rpc = RPContext()
    pattern_ex = recode_pattern(rpc, pattern_ex)

    # evaluates the pattern expression inline
    :( patmethod($quotevalue(rpc.vars), ($pattern_ex), ($quotevalue(body))) )
end
macro patmethod(fdef)
    signature, body = split_fdef(fdef)
    @expect is_expr(signature, :call)
    pattern_ex = quoted_tuple(signature.args[2:end])

    code_patmethod(pattern_ex, body)
end


# -- @pattern -----------------------------------------------------------------

type PatternMethodTable
    fname::Symbol
    methods::Vector{PatternMethod}

    PatternMethodTable(fname::Symbol) = new(fname, PatternMethod[])
end

add(mt::PatternMethodTable, m::PatternMethod) = push(mt.methods, m)

function dispatch(mt::PatternMethodTable, args::Tuple)
    for m in mt.methods
        matched, result = m.dispfun(args...)
        if matched;  return result;  end
    end
    error("no dispatch found for pattern function $(m.fname)$args")
end


const __patmethod_tables = Dict{Function,PatternMethodTable}()

macro pattern(fdef)
    code_pattern_fdef(fdef)
end
function code_pattern_fdef(fdef)
    signature, body = split_fdef(fdef)
    @expect is_expr(signature, :call)
    pattern_ex = quoted_tuple(signature.args[2:end])
#    method = patmethod(pattern, body)
    method_ex = code_patmethod(pattern_ex, body)

    fname = signature.args[1]
    qfname = quoted_expr(fname)
    @gensym fun mtable
    quote
        ($fun) = nothing
        try
            ($fun) = ($fname)
        end
        if is(($fun), nothing)
            ($mtable) = PatternMethodTable($qfname)
#            const ($fname) = create_pattern_function(($mtable))
            const ($fname) = (args...)->dispatch(($mtable), args)
            __patmethod_tables[$fname] = ($mtable)
        else
            if !(isa(($fun),Function) && has(__patmethod_tables, ($fun)))
                error("\nin @pattern method definition: ", ($string(fname)), 
                " is not a pattern function")
            end
            ($mtable) = __patmethod_tables[$fun]
        end
        add(($mtable), ($method_ex))
    end
end
