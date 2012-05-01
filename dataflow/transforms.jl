

#load("dag.jl")

# == ordering =================================================================

type OrderContext
    dag::DAG
    nodeset::Set{Node}

    OrderContext(dag::DAG) = new(dag, Set{Node}())
end

function order!(dag::DAG)
    dag.order = Node[]
    dag.symnode_names = SymNodeTable()
    context = OrderContext(dag)
    for node in dag.bottom.args
        order_node(context, node)
    end
end

function order_node(context::OrderContext, node::Node)
    if has(context.nodeset, node); return; end
    add(context.nodeset, node)

    for arg in node.args;   order_node(context, arg);   end

    emit_to_order(context.dag, node)
end


# == RewriteContext ===========================================================

type RewriteContext{V}  # <: Context
    results::Dict{Node,Node}
    visitor::V

    RewriteContext(visitor::V) = new(Dict{Node,Node}(),visitor)
end

RewriteContext{V}(visitor::V) = RewriteContext{V}(visitor)


function rewrite_node(context::RewriteContext, node::Node)
    if has(context.results, node)
        return context.results[node]
    end
    # rewrite node args
    args = {rewrite_node(context, arg) | arg in node.args}
    # rewrite the node

    # todo: remove!
#    global __node = node
#    node  = __node

#     println("rewrite_node:")
#     println("\t node             = \t", node)    
#     println("\t node.val         = \t", typeof(node.val))
#     println("\t typeof(node)     = \t", typeof(node))
#     println("\t typeof(node.val) = \t", typeof(node.val))
#     println("\t isa(node, SymNode)) =\t", isa(node, SymNode))
#     println("\t isa(node, TupleNode)) =\t", isa(node, AssignNode))



    subsnode = Node(node.val, args)
    subsnode.name = node.name
    newnode = rewrite(context, subsnode)
    # store the results and return
    context.results[node] = newnode
    newnode
end

function rewrite_dag(dag::DAG, visitor)
    context = RewriteContext(visitor)
    bottom = rewrite_node(context, dag.bottom)
    DAG(bottom), context
end


# -- Scatterer ----------------------------------------------------------------

type ScatterVisitor; end
typealias ScatterContext RewriteContext{ScatterVisitor}

function rewrite(c::ScatterContext, node::Union(CallNode,RefNode))
    newnode = Node(node.val, {node.args[1], 
                   {scatter_input(c, arg) | arg in node.args[2:end]}...})
    newnode.name = node.name
    newnode
end
rewrite(::ScatterContext, node::Node) = node

function scatter_input(c::ScatterContext, node::SymNode) 
#    print("scatter_input: node = ", node)
    RefNode(node, EllipsisNode(SymNode(:indvars, :input)))
end
scatter_input(c::ScatterContext, node::Node) = node
