
load("utils.jl")


# == Context ==================================================================

type SymEntry
    value::Any
end

type Context
    symbols::HashTable{Symbol,SymEntry}  # current symbol bindings    
    emit_function::Function
    props::HashTable{Symbol,Any}

    function Context(symbols::HashTable, emit, props::HashTable{Symbol}) 
        # make sure props can hold any value without converting it
        props = convert(HashTable{Symbol,Any}, props)        

        # convenience access through c.lhs, defalt = false
        lhs = setdefault(props, :lhs, false) 

        new(symbols, emit, props, lhs)
    end

    lhs::Bool
end

function child(c::Context, new_props) 
    props = copydict(c.props)
    props[:lhs] = false
    props.update(new_props)
    Context(c.symbols, c.emit_function, props)
end
child(c::Context) = child(c::Context, ())


# -- Flatten ------------------------------------------------------------------

flatten(context, ex::Any) = ex
flatten(context, exprs::Vector) = { flatten(context, ex) | ex in exprs }

function flatten(context, sym::Symbol)
    if has(context, sym)
        return context[sym].value         # return current symbol value
    else
        return create_argument(context, sym)  # create new argument named sym
    end
end

function flatten(context, ex::Expr)
    if context.lhs
        if ex.head == :ref
            
        end
        error("Unimplemented as LHS: ex = :$(ex)")
    else
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
            lhs = flatten(child(context,(@dict lhs=true)), ex.args[1])
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
end
