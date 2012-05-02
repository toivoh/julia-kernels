
load("cached.jl")
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


# -- New Scatterer ------------------------------------------------------------

@cached function scattered(c::Context, node::SymNode)
    if node.val.name == :(... )
        EllipsisNode(SymNode(:indvars, :input))
    else
        return RefNode(node, EllipsisNode(SymNode(:indvars, :input)))
    end
end
@cached function scattered(c::Context, node::Union(CallNode,RefNode))
    args = {node.args[1]::SymNode, 
            {scattered(c, arg) | arg in node.args[2:end]}... }
    Node(node, args)
end
@cached function scattered(c::Context, node::Node)
    Node(node, { scattered(c, arg) | arg in node.args } )
end

function scattered(dag::DAG)
    context = Cache()
    bottom = scattered(context, dag.bottom)
    DAG(bottom)
end


# -- Count node uses ----------------------------------------------------------

@cached function count_uses(c::Context, node::Node)
    args = { count_uses(c, arg) | arg in node.args }
    newnode = Node(node, args)    
#     newnode.uses = {}#WeakRef[]
    newnode.num_uses = 0

    for arg in args
        nu = (arg.num_uses += 1)
        if (nu == 2) && (is(arg.name, nothing)) && !isa(arg, TerminalNode)
            arg.name = gensym()
        end
    end
#     for arg in args;  push(arg.uses, WeakRef(newnode));  end
    newnode
end

function count_uses(dag::DAG)
    context = Cache()
    bottom = count_uses(context, dag.bottom)
    DAG(bottom)    
end
