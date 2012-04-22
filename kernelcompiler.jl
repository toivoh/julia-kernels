

flatten(ex::Any, return_symbol::Bool) = ex
function flatten(ex::Expr, return_symbol::Bool)

# Returns the value of an Expr as a symbol
#
# Emits instruction exprs of the forms
# dest = y
# dest[inds] = y
# where y and inds[k] are symbol/primitive op
# Primitive op = op with symbol-only arguments

    if ex.head == :block
        value = nothing
        for subex in ex.args
            value = flatten(subex, return_symbol)
        end
        return value
    elseif ex.head == :line # ignore line numbers
        return nothing # CONSIDER: could this shadow the last actual value?
    elseif ex.head == :(=)  # assignment
        lhs = flatten(ex.args[1], false)
        rhs = flatten(ex.args[2], false)
        produce(expr(:(=), lhs, rhs))
        return rhs # or lhs?
    elseif (ex.head == :call) || (ex.head == :ref)
        #args = map(flatten, ex.args, true)

        nargs = length(ex.args)
        args = cell(nargs)
        for k=1:nargs;   args[k] = flatten(ex.args[k], true);   end

        result = expr(ex.head, args...) # flattened invocation
        if return_symbol # store the result to an intermediate?
            intermediate = gensym() 
            produce(expr(:(=), intermediate, result))
            result = intermediate
        end
        return result
    else
        error("Unimplemented expr type: head = :$(ex.head)")
    end
end

# -- Test code ----------------------------------------------------------------

function print_flattened(ex)
    exprs = @task flatten(ex, true)
    for ex in exprs
        println(ex)
    end
end


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
end

# flatten
# single-assign
# process array form
# scalarize
