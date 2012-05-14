
load("utils/req.jl")
req("utils/utils.jl")
req("unify/unify.jl")


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
    code::Vector

    PMContext() = new(Dict{PVar, PVarEntry}(), {})
end

PMContext(rpc::RPContext) = PMContext(rpc.vars)
function PMContext(vars::Dict)
    c = PMContext()
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


function code_iffalse_retfalse(pred)
    :(if !($pred)
        return false
    end)
end

code_pmatch(c::PMContext, ::NonePattern,::Symbol) = error("code_pmatch: "*
                                                  "pattern never matches")
function code_pmatch(c::PMContext, p::PVar,xname::Symbol)
    entry = get_entry(c, p)
    if entry.isassigned
        emit(c, code_iffalse_retfalse(:( isequal(($entry.name),($xname))) ))
    else
        if !isuniversal(p.dom)
            emit(c, code_iffalse_retfalse(code_contains(p.dom,xname)))
        end
        emit(c, :(
            ($entry.name) = ($xname)
        ))
        entry.isassigned = true
    end
end
function code_pmatch(c::PMContext, p::RuntimeValue,xname::Symbol)
    emit(c, code_iffalse_retfalse(:( isequal(($p.name),($xname)) )))
end
function code_pmatch(c::PMContext, p,xname::Symbol)
    @assert isatom(p)
    emit(c, code_iffalse_retfalse(:( isequal(($quoted_expr(p)),($xname)) )))
end
function code_pmatch_list(T, c::PMContext, ps,xname::Symbol)
    np = length(ps)
    emit(c, code_iffalse_retfalse( :(
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

macro ifmatch(ex)
    code_ifmatch(ex)
end
function code_ifmatch(ex)
    @expect is_expr(ex, :let)
    body = ex.args[1]
    #matches = ex.args[2:end]
    @expect length(ex.args) == 2
    match = ex.args[2]

    @expect is_expr(match, :(=), 2)
    pattern, valex = match.args[1], match.args[2]
    valname = gensym("value")
    
    rpc = RPContext()
    pattern = recode_pattern(rpc, pattern)
    pattern = eval(pattern)

    pmc=PMContext(rpc)
    code_pmatch(pmc, pattern,valname)
    push(pmc.code, :true)
#    foreach(pprintln, pmc.code)

    varnames = {kv[2].name for kv in pmc.vars}
    pmatch

    quote
        let ($valname)=($valex)
            local ($varnames)
            if let
                ($pmc.code...)
            end
                ($body)
            end
        end
    end
end