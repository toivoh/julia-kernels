
load("utils/cached.jl")
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


# -- evaluation ---------------------------------------------------------------

type Context{C}
    c::C
    cache::Cache
    
    Context(c::C) = new(c, Cache())
    Context() = new(C(), Cache())
end
Context{C}(c::C) = Context{C}(c)

cacheentry(f::Function, c::Context, args...) = cacheentry(f, c.cache, args...)

evaluate(c::Context, ns::Nodes) = { (@cached evaluate(c, node))|node in ns }
evaluate(c::Context, node::Node) = Node(node, (@cached evaluate(c, node.args)))


# -- scattering fusion --------------------------------------------------------

type Scatterer; end
typealias ScatterContext Context{Scatterer}

scattered(node::Node) = evaluate(ScatterContext(), node)
function evaluate(c::ScatterContext, node::SymNode)
    # todo: eliminate duplicate indvars?
    ellipsis = EllipsisNode(SymNode(:indvars, :local))
    node.val.name == :(... ) ? ellipsis : RefNode(node, ellipsis)
end
function evaluate(c::ScatterContext, node::Union(CallNode,RefNode))
    Node(node, { node.args[1]::SymNode, evaluate(c, node.args[2:end])... })
end


# -- Count node uses ----------------------------------------------------------

type UseCounter; end
typealias UseCountContext Context{UseCounter}

count_uses(node::Node) = evaluate(UseCountContext(), node)
function evaluate(c::UseCountContext, node::Node)
    node = Node(node, evaluate(c, node.args))
    for arg in node.args
        nu = (arg.num_uses += 1)
        if ((nu == 2) && (is(arg.name, nothing)) && isa(arg, OpNode))
            arg.name = gensym()
        end
    end
    node
end
