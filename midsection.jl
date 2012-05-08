
load("dag/transforms.jl")


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
    # todo: use first line once ref result type bug is fixed
#    Node(node, { node.args[1]::SymNode, evaluate(c, node.args[2:end])... })
    Node(node, { node.args[1]::SymNode, 
                 evaluate(c, Node[node.args[2:end]...])... })
end
