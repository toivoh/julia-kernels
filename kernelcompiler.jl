
# -- Context --------------------------------------------------------------------

type Context
    symbols::HashTable{Symbol,Any}
    inputs::Vector

    nodes::Vector

    Context() = new(HashTable{Symbol,Any}(), {}, {})
end

emit(context::Context, ex) = append!(context.nodes, {ex})

# delegate to HashTable
has(context::Context, name::Symbol) = has(context.symbols, name)
ref(context::Context, name::Symbol) = ref(context.symbols, name)
assign(context::Context, val, name::Symbol) = assign(context.symbols, val, name)

function create_input(context::Context, name::Symbol)
    input_name = name 
    append!(context.inputs, {input_name})  # list the new input
    context[name] = input_name             # and add it to the symbol table
    return input_name
end


# -- New flatten ----------------------------------------------------------------

# flatten(context, ex)
#
# Returns the value of an Expr as a symbol
# Updates context with symbol bindings
# Emits instructions to context:
#   * assignments dest = op(args...)
#   * indexed assignment dest[inds...] = source
# where dest, source, and each element of args and inds are terminals.

flatten(context, ex::Any) = ex

function flatten(context, sym::Symbol)
    if has(context, sym)
        return context[sym]         # return current symbol value
    else
        return create_input(context, sym)  # create new input named sym
    end
end

function flatten(context, ex::Expr)
    if ex.head == :block
        value = nothing
        for subex in ex.args
            value = flatten(context, subex)
        end
        return value
    elseif ex.head == :line # ignore line numbers
        return nothing # CONSIDER: could this shadow the last actual value?
    elseif ex.head == :(=)  # assignment
        lhs = ex.args[1]
        rhs = flatten(context, ex.args[2])
        
        if isa(lhs, Symbol)
            # straight assignment: just update symbol table
            context[lhs] = rhs
            return rhs
        elseif (isa(lhs, Expr)) && (lhs.head == :ref)
            # indexed assignment
            lhs = flatten_invocation(context, lhs)
            emit(context, expr(:(=), lhs, rhs))
            return rhs
        end
        error("Unimplemented: lhs = ($lhs)")
    elseif (ex.head == :call) || (ex.head == :ref)
        node = gensym() 
        emit(context, expr(:(=), node, flatten_invocation(context, ex)))
        return node
    else
        # error("Unimplemented expr type: head = :$(ex.head)")
        error("Unimplemented: ex = :$(ex)")
    end    
end

function flatten_invocation(context, ex::Expr)
    args = {flatten(context, arg) | arg in ex.args}
    expr(ex.head, args...) # flattened invocation
end





# -- Test code ----------------------------------------------------------------



code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
end

# flatten
# single-assign
# process array form
# scalarize
