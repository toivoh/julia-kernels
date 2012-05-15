

load("utils/req.jl")
req("utils/utils.jl")
req("pdispatch/pmatch.jl")


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
