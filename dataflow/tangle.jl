
load("dag.jl")

is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))
function expect_expr(ex, head::Symbol)
    if !is_expr(ex, head)
        error("expected expr(:$head,...), found $ex")
    end
end

# macro setdefault(args...)
#     # allow @setdefault(refexpr, default)
#     if (length(args)==1) && is_expr(args[1], :tuple)
#         args = args[1].args
#     end
#     refexpr, default = tuple(args...)
macro setdefault(refexpr, default)

    expect_expr(refexpr, :ref)
    dict_expr, key_expr = tuple(refexpr.args...)
    @gensym dict key

    quote
        ($dict)::Associative = ($dict_expr)
        ($key) = ($key_expr)
        if has(($dict), ($key))
            ($dict)[($key)]
        else
            ($dict)[($key)] = ($default) # returns the newly inserted value
        end
    end
end



# == Context ==================================================================

typealias SymbolTable Dict{Symbol,Node}

type Context
    symbols::SymbolTable  # current symbol bindings    
    dag::DAG
end

Context(symbols::SymbolTable) = Context(symbols, DAG())
Context() = Context(SymbolTable())


# == tangle ===================================================================

#tangle(c::Context, exprs::Vector) = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
function tangle(c::Context, exprs::Vector) 
    nodes = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
    # println("\nnodes = $nodes")
    # println("T=$(typeof(nodes))")
    nodes
end


tangle(::Context, ex::Any) = LiteralNode(ex)   # literal
function tangle(context::Context, name::Symbol)
    @setdefault context.symbols[name] SymNode(name, :input)
end
function tangle(context::Context, ex::Expr)
    if ex.head == :line # ignore line numbers
        return EmptyNode()
    elseif ex.head == :block    # exprs...
        value = LiteralNode(nothing)
        for subex in ex.args
            value = tangle(context, subex)
        end
        return value
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = tangle_lhs(context, ex.args[1])
        rhs = tangle(context, ex.args[2])
        return entangle_assignment(context, lhs, rhs)
    elseif (ex.head == :call)
        fname = ex.args[1]
        op = @setdefault context.symbols[fname] SymNode(fname, :call)
        # println(ex.args[2:end])
        args = tangle(context, ex.args[2:end])
        # println(args)
        return CallNode(op, args)
    elseif (ex.head == :ref)
        args = tangle(context, ex.args)
        # println("args=$args")
        # println("args[2:n]=$(args[2:end])")
        # println("T=$(typeof(args))")
        #RefNode(  A::Node, inds::Vector{Node})        
        args[1]::Node
        args[2:end]::Vector{Node}
        return RefNode(args[1], args[2:end])
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- tangle_lhs --------------------------------------------------------------
# Tangle a scalar-valued lhs expr

tangle_lhs(context::Context, name::Symbol) = SymNode(name, :local)
function tangle_lhs(context::Context, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    oname = ex.args[1]
    output = @setdefault context.symbols[oname] SymNode(oname, :output)
    inds = tangle(context, ex.args[2:end])
    RefNode(output, inds)
end


# -- entangle_assignment(context::Context, lhs, rhs) --------------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function entangle_assignment(context::Context, lhs::SymNode, rhs::Node) 
    # straight assignment: just store in symbol table
    context.symbols[lhs.val.name] = rhs # return rhs
end
function entangle_assignment(context::Context, lhs::RefNode, rhs::Node)
    # indexed assignment to output
    dest = (lhs.val.A)::SymNode
    # bind the assignnode to the name of dest
    context.symbols[dest.val.name] = assignnode(lhs, rhs)
    # and evaluate to the rhs
    rhs
end


# == Some printing ============================================================

function print_dag(dag::DAG) 
    println("nodes (topsort):")
    for node in dag.topsort; println("\t", node); end
end
print_symtable(st::SymbolTable) = (for (k, v) in st; println("\t$k = $v"); end)

function print_context(context::Context) 
    print("Symbols at end:")
    print_symtable(context.symbols)
    print_dag(context.dag)
end