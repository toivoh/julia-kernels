
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

type RPVarEntry
    name::Symbol   
    T_expr
    temp_name::Symbol
end
function code_create_pvar(e::RPVarEntry)
    :( ($e.temp_name)=pvar(($quotevalue(t.name)), ($T_expr)) )
end

type RPContext
    vars::Dict{Symbol,RPVarEntry}
    unmatchable::Bool # todo: use!

    RPContext() = new(Dict{Symbol,PVar}(), false)
end

#getvar(c::RPContext, name::Symbol) = getvar(c, name, quotevalue(Any))
getvar(c::RPContext, name::Symbol) = getvar(c, name, :Any)
function getvar(c::RPContext, name::Symbol, T_expr)
    if has(c.vars, name)
        entry = c.vars[name]
        if !isequal(T_expr, entry.T_expr)
            error("conflicting types in pattern: $(name)::$(entry.T_expr) "
                  *" vs $(name)::$(T_expr)")
        end
    else
        entry = RPVarEntry(name, T_expr, gensym(string(name)))
        c.vars[name] = entry
    end
    entry.temp_name
end


function recode_pattern(ex)
    rpc = RPContext()
    pattern_ex = recode_pattern(rpc, ex)
    
    quote
        let ($pvar_defs...)
            ($pattern_ex)
        end
    end
end


function recode_pattern(c::RPContext, ex::Expr)
    head, args = ex.head, ex.args
    nargs = length(args)
    if head == doublecolon
        @expect nargs==2
        return getvar(c, args[1], args[2])
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
recode_pattern(c::RPContext, sym::Symbol) = getvar(c, sym)
recode_pattern(c::RPContext, ex) = ex # other terminals
