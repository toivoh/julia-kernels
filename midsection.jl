
load("utils/req.jl")
req("dag/transforms.jl")


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


# -- scatter propagation ------------------------------------------------------

type ScatterPropagator; end
typealias ScatterPropContext Context{ScatterPropagator}

scatter_propagated(sink::Node) = evaluate(ScatterPropContext(), sink)
function evaluate(c::ScatterPropContext, node::CallNode)
    if get_op(node).val == SymbolEx(:scatter, :call)
        args = get_callargs(node)
        @expect length(args)==1
        return (@cached scattered(c, args[1]))
    else
        return default_evaluate(c, node)
    end
end

function scattered(c::ScatterPropContext, ns::Vector)#Nodes)
    { (@cached scattered(c, node))|node in ns }
end
function scattered(c::ScatterPropContext, node::CallNode)
    op = get_op(node).val
    if op == SymbolEx(:scatter, :call)
        # let scatter*scatter = scatter
        args = get_callargs[node]
        @expect length(args)==1
        return scattered(c, args[1])
    else
        op = scattered_op(op)
        args = scattered(c, get_callargs(node))
        return CallNode(op, args...)
    end
end
# todo: scattered for other node types: RefNode, ...more?
function scattered(c::ScatterPropContext, node::SymNode)
    @expect node.val.kind == :input "expected kind == :input, got $(node.val.kind)"
    RefNode(node, SymNode(:..., :symbol))
end

function scattered_op(ex::SymbolEx)
    @expect ex.kind == :call
    op = ex.name
    
    if contains([:*, :/, :\ ], op)
        error("scattered: cannot scatter op = ", op)
    end
    SymNode(op, :call)
end