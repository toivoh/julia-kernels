
load("dag.jl")


# == TangleContext ============================================================

typealias SymbolTable Dict{Symbol,Node}

type TangleContext  # <: Context
    symbols::SymbolTable                        # current symbol bindings
    dag::DAG
    #last_actions::Vector{ActionNode}

#    TangleContext() = new(SymbolTable(), DAG(), ActionNode[])
    TangleContext() = new(SymbolTable(), DAG())
end

emit(c::TangleContext, node::Node) = emit(c.dag, node)
#emit(c::TangleContext, node::Node) = push(c.dag.order, node)
# function emit(c::TangleContext, node::Node)
#     push(c.dag.order, node)
#     if isa(node, SymNode)
#         names = @setdefault c.symnode_names[node.val.kind] Symbol[]
#         push(names, node.val.name)
#     end
# end


# == tangle ===================================================================

function tangle(code)
    context = TangleContext()
    value = tangle(context, code)
    dag = context.dag
    dag.value = value
    dag.bottom = TupleNode(value, dag.bottom_actions...)
    if is((value::Node).name, nothing)
        value.name = :value
    end
    value, context.dag, context
end


#tangle(c::TangleContext, exprs::Vector) = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
function tangle(c::TangleContext, exprs::Vector) 
    nodes = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
    # println("\nnodes = $nodes")
    # println("T=$(typeof(nodes))")
    nodes
end


tangle(c::TangleContext, ex::Any) = LiteralNode(ex)   # literal
function tangle(context::TangleContext, name::Symbol)
    @setdefault context.symbols[name] SymNode(name, :input)
end
function tangle(context::TangleContext, ex::Expr)
    if ex.head == :line # ignore line numbers
        # don't need to emit this one; shouldn't remain in the DAG
        return NoNode() 
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
        return CallNode(op, args...)
    elseif (ex.head == :ref)
        return RefNode(tangle(context, ex.args)...)
    elseif (ex.head == :(...))  # todo: test!
        return EllipsisNode(tangle(context, ex.args)...)
    elseif (ex.head == :tuple)  # todo: test!
        return TupleNode(tangle(context, ex.args)...)
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- tangle_lhs --------------------------------------------------------------
# Tangle a scalar-valued lhs expr; return lone symbols unadorned

#tangle_lhs(context::TangleContext, name::Symbol) = SymNode(name, :local)
tangle_lhs(context::TangleContext, name::Symbol) = name
function tangle_lhs(context::TangleContext, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    oname = ex.args[1]
    output = @setdefault context.symbols[oname] SymNode(oname, :output)
    inds = tangle(context, ex.args[2:end])
    RefNode(output, inds...)
end


# -- entangle_assignment(context::TangleContext, lhs, rhs) --------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function entangle_assignment(context::TangleContext, lhs::Symbol, rhs::Node) 
    # straight assignment: just store in symbol table
    rhs.name = lhs # remember this alias for rhs
    context.symbols[lhs] = rhs # return rhs
end
function entangle_assignment(context::TangleContext, lhs::RefNode, rhs::Node)
    # indexed assignment to output
    dest = get_A(lhs)::SymNode
    node = AssignNode(lhs, rhs, context.dag.bottom_actions...)
    # bind the assignnode to the name of dest
    context.symbols[dest.val.name] = node
    context.dag.bottom_actions = [node]
    # and evaluate to the rhs
    rhs
end


# == Untangle =================================================================

toexpr(ex::LiteralEx) = ex.value
toexpr(ex::SymbolEx)  = ex.name

toexpr(ex::CallEx,     args...) = expr(:call,  args...)
toexpr(ex::RefEx,      args...) = expr(:ref,   args...)
toexpr(ex::TupleEx,    args...) = expr(:tuple, args...)
toexpr(ex::EllipsisEx, args...) = expr(:(...), args...)

toexpr(ex::AssignEx,   args...) = expr(:(=),   args...)


function untangle(dag::DAG)
    exprs = Any[]
    for node in dag.order
        if isa(node, AssignNode)
            ex = untangle(node, true)
            push(exprs, ex)
        elseif !is(node.name, nothing)
            ex = untangle(node, true)
            ex = expr(:(=), node.name, ex)
            push(exprs, ex)
        end
    end
    exprs
end

untangle(nodes::Vector{Node}, fe::Bool) = {untangle(node, fe) | node in nodes}
untangle(node::TerminalNode, force_expand::Bool)  = toexpr(node.val)
function untangle(node::OpNode, force_expand::Bool)
    if force_expand || is(node.name, nothing)
        return toexpr(node.val, untangle(node.args))
    else
        return node.name
    end
end
untangle(arg) = untangle(arg, false)


# == Some printing ============================================================

function print_list(list::Vector) 
    for item in list; println("\t", item); end
end
function print_dag(dag::DAG) 
    println("nodes:")
    for node in dag.order; println("\t", node); end
end
print_symtable(st::SymbolTable) = (for (k, v) in st; println("\t$k = $v"); end)

function print_context(context::TangleContext) 
    println("SymNode names by kind:")
    for (k, names) in context.dag.symnode_names; println("\t$k:\t$names"); end
    println("Symbols at end:")
    print_symtable(context.symbols)
    println()
    print_dag(context.dag)
end