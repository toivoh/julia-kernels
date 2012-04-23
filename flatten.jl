
load("utils.jl")


# == Context ==================================================================

type SymEntry
    value::Any
end

type Context
    symbols::HashTable{Symbol,SymEntry}  # current symbol bindings    
    props::HashTable{Symbol,Any}         # context properties
    emit_function::Function              # sink for emitted instructions

    function Context(symbols::HashTable{Symbol,SymEntry}, props, emit) 
        # copy props (required!) and make sure it's the right type
        props = makedict(Symbol,Any,props)        

        # convenience access through c.lhs, defalt = false
        lhs = setdefault(props, :lhs, false)::Bool 

        new(symbols, props, emit, lhs)
    end
    
    lhs::Bool  # convenience access to props[:lhs]
end
Context(c::Context) = Context(c.symbols, c.props, c.emit_function)

function child(c::Context, new_props) 
# Create a child context from c:
#     Copy c
#     Replace properties given by makedict{Symbol}{Any}(new_props)
#     Set lhs=false if not explicitly given

    # copy c
    c = Context(c) 
    # modifies props: only at creation!
    c.props[:lhs] = false
    c.props.update(new_props)
    c
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


st=HashTable{Symbol,SymEntry}()
emit=(ex)->()
props=(@dict lhs=true)
