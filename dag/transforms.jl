
# transforms.jl
# =============
# Transformations on DAG:s
#


load("utils/cached.jl")
load("dag/dag.jl")


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


# -- topsort iteration --------------------------------------------------------

type Topsorter; end
typealias TopsortContext Context{Topsorter}

forward(sink::Node) = @task evaluate(TopsortContext(), sink)

function evaluate(c::TopsortContext, node::Node)
    evaluate(c, node.args)
    produce(node)
    nothing
end


# -- nodewise rewrite ---------------------------------------------------------

type Rewriter; rewrite::Function; end
typealias RewriteContext Context{Rewriter}

rewrite_dag(sink::Node, fun::Function) = evaluate(Context(Rewriter(fun)), sink)
function evaluate(c::RewriteContext, node::Node)
    args = evaluate(c, node.args)
    c.c.rewrite(node, args)
end


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
    Node(node, { node.args[1]::SymNode, evaluate(c, Node[node.args[2:end]...])... })
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


# -- Collect SymNode names ----------------------------------------------------

function collect_symnode_names(sink::Node)
    allnames = Dict{Symbol,Vector{Symbol}}()
    for node in forward(sink)
        if isa(node, SymNode)
            names = @setdefault allnames[node.val.kind] Symbol[]
            push(names, node.val.name)
        end        
    end
    allnames
end
