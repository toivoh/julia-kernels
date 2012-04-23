
#counter=5;

load("utils.jl")


is_expr(head, ex) = (isa(ex, Expr) && ex.head == head)


# == Context ==================================================================

type SymEntry
    value::Any
    kind::Symbol
end

type Context
    symbols::HashTable{Symbol,SymEntry}  # current symbol bindings    
    props::HashTable{Symbol,Any}         # context properties
    emit_function::Function              # sink for emitted instructions

    function Context(symbols::HashTable{Symbol,SymEntry}, props_seq, emit) 
        # copy props (required!) and make sure it's the right type
        props = makedict(Symbol,Any,props_seq...)        

        # convenience access through c.lhs, c.scalar; defalts = false, true
        lhs = setdefault(props, :lhs, false)::Bool 
        scalar = setdefault(props, :scalar, true)::Bool 

        new(symbols, props, emit, Symbol[], Symbol[], lhs, scalar)
    end

    inputs::Vector{Symbol}
    outputs::Vector{Symbol}
    
    # convenience access to props[:lhs], props[:scalar]
    lhs::Bool  
    scalar::Bool
end
Context(c::Context) = Context(c.symbols, (c.props,), c.emit_function)
function Context(c::Context, props_seq...) 
    Context(c.symbols, {c.props, props_seq...}, c.emit_function)
end

function child(c::Context, new_props) 
# Create a child context from c:
#     Copy c
#     Replace properties given by makedict{Symbol}{Any}(new_props)
#     Set lhs=false, scalar=true if not explicitly given

#     # copy c
#     c = Context(c) 
#     # modifies props: only at creation!
#     c.props[:lhs] = false
#     c.props[:scalar] = true
#     update(c.props, new_props)
#     return c
    c = Context(c, (@dict lhs=false scalar=true), new_props)
end
child(c::Context) = child(c::Context, ())


function create_argument(c::Context, name::Symbol)
    if has(context.props, :verbose)
        println("create_argument:")
        println("\tcontext = $context")
        println("\tname = $name")
        println()
    end

    if context.scalar; error("unbound scalar $name"); end

    arg_name = name 
    if c.lhs # create output
        c.symbols[name] = SymEntry(arg_name, :output)
        append!(context.outputs, {arg_name})
    else     # create input
        c.symbols[name] = SymEntry(arg_name, :input)
        append!(context.inputs, {arg_name})
    end
    return arg_name
end


# -- Flatten ------------------------------------------------------------------

flatten(c::Context, ex::Any) = ex
flatten(c::Context, exprs::Vector) = { flatten(c, ex) | ex in exprs }

# like flatten(context, exprs::Vector), but only returns last value
function flatten_block(c::Context, exprs::Vector) 
    value = nothing
    for ex in exprs
        value = flatten(c, ex)
    end
    value
end

function flatten(context::Context, sym::Symbol)
    if has(context.props, :verbose)
        println("flatten symbol:")
        println("\tcontext = $context")
        println("\tcontext.symbols = $(context.symbols)")
        println("\tsym = $sym")
        println()
    end
   
    if context.lhs
        if context.scalar # sym is an intermediate
            return sym
        else              # sym is an output
            return create_argument(context, sym)
        end
    else # rhs
        println("rhs")
        if has(context.symbols, sym)
            println("\thas\n")
            return context[sym].value             # return current symbol value
        else
            if context.scalar
                println("\tscalar:flatten\n")
                return flatten(context, expr(:call, :readinput, sym)) 
            else
                println("\tcreate_argument\n")
                println("\tcontext = $context")
                # create new argument named sym
                return create_argument(context, sym)
            end
        end
    end
end

function flatten(context::Context, ex::Expr)
    if has(context.props, :verbose)
        println("flatten:")
        println("\tcontext = $context")
        println("\tex = $ex")
        println()
    end

#     global counter
#     counter -= 1
#     if counter <= 0; error(); end

    if context.lhs
        if ex.head == :ref 
            # indexed assignment
            dest = flatten(ex.args[1], (@dict lhs=true scalar=false))
            inds = flatten(ex.args[2:end])
            return expr(:ref, dest, inds...)
        end
        error("Unimplemented as LHS: ex = :$(ex)")
    else   # rhs Expr
        if ex.head == :block
            return flatten_block(context, ex.args)            
        elseif ex.head == :line # ignore line numbers
            return nothing # CONSIDER: could this shadow the last actual value?
        elseif ex.head == :(=)  # assignment
            lhs = ex.args[1]
            rhs = flatten(context, ex.args[2])
            
            if has(context.props, :verbose)
                println("assignment:")
                println("\tlhs = $lhs")
                println("\trhs = $rhs")
            end


            if isa(lhs, Symbol)
                # straight assignment: just update symbol table
                context.symbols[lhs] = context.symbols[rhs]
                return rhs
            elseif (isa(lhs, Expr)) && (lhs.head == :ref)
                # indexed assignment
                lhs = flatten(child(context,(@dict lhs=true)), lhs)
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

function flatten_invocation(context::Context, ex::Expr)
    if has(context.props, :verbose)
        println("flatten_invocation:")
        println("\tcontext = $context")
        println("\tex = $ex")
        println()
    end
        
#     global flc = context
#     global fle = ex

    if ex.head == :call
        arg1 = ex.args[1]
        if arg1 == :readinput
            arg2 = flatten(child(context,(@dict scalar=false)), ex.args[2])
            @assert length(ex.args) == 2
            return expr(ex.head, arg1, arg2)
        else
            argsrest =  flatten(context, ex.args[2:end])
            return expr(ex.head, arg1, argsrest...)
        end
    else
        arg1 = flatten(child(context,(@dict scalar=false)), ex.args[1])
        argsrest =  flatten(context, ex.args[n_ns:end])
        return expr(ex.head, arg1, argsrest...)
    end
end



# -- Test code ----------------------------------------------------------------

code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
end

symbols = HashTable{Symbol,SymEntry}()
#props = ()
props = @dict verbose=true
out_code = {}
emit = ex->append!(out_code, {ex})
context = Context(symbols, (props,), emit)

value = flatten(context, code)
