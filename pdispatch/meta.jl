
load("utils/req.jl")
req("pdispatch/patterns.jl")


function split_fdef(fdef::Expr)
    @expect (fdef.head == :function) || (fdef.head == :(=))
    @expect length(fdef.args) == 2
    signature, body = tuple(fdef.args...)
    @expect is_expr(signature, :call)
    @expect length(signature.args) >= 1
    (signature, body)
end
split_fdef(f::Any) = error("split_fdef: expected function definition, got\n$f")


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
