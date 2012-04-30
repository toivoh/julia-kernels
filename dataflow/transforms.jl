

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
    dag::DAG
    results::Dict{Node,Node}
    visitor::V

    RewriteContext(visitor::V) = new(DAG(), Dict{Node,Node}(),visitor)
end

function rewrite_node(context::RewriteContext, node::Node)
    # subsitute node args
    newargs = Node[{context.results[arg] | arg in node.args}...]
    subsnode = Node(node.val, newargs)

    # rewrite the node
    newnode = rewrite(context, subsnode)

    # store the results
    context.results[node] = newnode
    newnode
end

function rewrite_dag(dag::DAG)
    for node in dag.nodes
        emit(dag, rewrite_node(context, node))
    end
    dag
end


# -- Scatterer ----------------------------------------------------------------

type Scatterer
end
typealias ScatterContext RewriteContext{Scatterer}

function rewrite(c::ScatterContext, node::Union(CallNode,RefNode))
    args = Node[node.args[1], {scatter_input(c, arg) | arg in node.args[2:end]}...]
end
rewrite(::ScatterContext, node::Node) = node

function scatter_input(c::ScatterContext, node::SymNode) 
    RefNode(node, EllipsisNode(SymNode(:indvars, :input)))
end
scatter_input(c::ScatterContext, node::Node) = node
