
# -- Context --------------------------------------------------------------------

type Context
    symbols::HashTable{Symbol,Any}  # current symbol bindings
    arguments::Vector               # unbound arguments

    code::Vector  # flattened output

    Context() = new(HashTable{Symbol,Any}(), {}, {})
end

emit(context::Context, ex) = append!(context.code, {ex})

# delegate to HashTable
has(context::Context, name::Symbol) = has(context.symbols, name)
ref(context::Context, name::Symbol) = ref(context.symbols, name)
assign(context::Context, val, name::Symbol) = assign(context.symbols, val, name)

function create_argument(context::Context, name::Symbol)
    arg_name = name 
    append!(context.arguments, {arg_name})  # list the new argument
    context[name] = arg_name                # and add it to the symbol table
    return arg_name
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
flatten(context, exprs::Vector) = { flatten(context, ex) | ex in exprs }

function flatten(context, sym::Symbol)
    if has(context, sym)
        return context[sym]         # return current symbol value
    else
        return create_argument(context, sym)  # create new argument named sym
    end
end

function flatten(context, ex::Expr)
    if ex.head == :block
        if isempty(ex.args)
            return nothing
        else
            values = flatten(context, ex.args)
            return values[end]
        end
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
    if ex.head == :call
        # Don't flatten operation: avoid making arguments of +, sin, ...
        # Don't need non-terminal ops?
        return expr(ex.head, ex.args[1], flatten(context, ex.args[2:end])...)
    else
        return expr(ex.head, flatten(context, ex.args)...)
    end
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
