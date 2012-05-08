
# transforms.jl
# =============
# Transformations on DAG:s
#

load("utils/req.jl")
req("utils/cached.jl")
req("dag/dag.jl")


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


# -- Name nodes with fanout > 1 -----------------------------------------------

name_fanout_nodes(sink::Node) = rewrite_dag(sink, namefanout_rewrite)

function namefanout_rewrite(oldnode::Node, args::Vector)
    for arg in args
        nu = (arg.num_uses += 1)
        if !has_name(arg) && (nu >= 2) && isa(arg, OpNode)
            arg.name = gensym()
        end
    end
    Node(oldnode, args)
end


# -- Make sure named nodes have unique names ----------------------------------

function name_nodes_uniquely(sink::Node)
    names = Set{Symbol}()
    rewrite_dag(sink, (node, args)->nameuniquely_rewrite(names, node, args))
end

function nameuniquely_rewrite(names::Set{Symbol}, oldnode::Node, args::Vector)
    node = Node(oldnode, args)
    if has_name(node)
        if has(names, get_name(node))
            node.name = gensym()
        end
        add(names, node.name)
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
