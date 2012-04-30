
load("utils.jl")


# == Node =====================================================================

abstract Expression

type Node{T<:Expression}
    val::T
    args::Vector{Node}

    name::Union(Symbol,Nothing)

    # raw Node constructors
    function Node(val::T, args...) 
        args::(Node...)
        node = new(val, Node[args...], nothing)
        if !check_args(node)
            error("Invalid node arguments for node type: node = $node")
        end
        node
    end

    # Used to forward typealias constructors to Node(T, args...)
    Node(targs...) = Node(T, targs...)
end

Node{T}(val::T, args...) = Node{T}(val, args...)


# -- expressions --------------------------------------------------------------

abstract Terminal  <: Expression
abstract Operation <: Expression
abstract FuncOp        <: Operation # operation without side effects
abstract Action        <: Operation # operation with side effects

typealias TerminalNode{T<:Terminal} Node{T}

typealias OpNode{T<:Operation}  Node{T}
typealias FuncOpNode{T<:FuncOp} Node{T}
typealias ActionNode{T<:Action} Node{T}

Node{T<:Operation}(::Type{T}, args...) = Node{T}(T(), args...)

get_args(node::Operation) = node.args


# -- terminals ----------------------------------------------------------------

type NoEx <: Terminal; end
type LiteralEx <: Terminal
    value
end
type SymbolEx <: Terminal
    name::Symbol
    kind::Symbol

    SymbolEx(name::Symbol, kind::Symbol) = new(name, kind)
end

typealias NoNode      Node{NoEx}
typealias LiteralNode Node{LiteralEx}
typealias SymNode     Node{SymbolEx}

Node{T<:Terminal}(::Type{T}, targs...) = Node{T}(T(targs...))
check_args{T<:Terminal}(node::Node{T}) = (length(node.args) == 0)


# -- functional operations (side effect free) ---------------------------------

type CallEx     <: FuncOp; end
type RefEx      <: FuncOp; end
type TupleEx    <: FuncOp; end
type EllipsisEx <: FuncOp; end

typealias CallNode     Node{CallEx}
typealias RefNode      Node{RefEx}
typealias TupleNode    Node{TupleEx}
typealias EllipsisNode Node{EllipsisEx}

get_op(node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]
check_args(node::CallNode) = (length(node.args) >= 1)

get_A(node::RefNode) = node.args[1]
get_inds(node::RefNode) = node.args[2:end]
check_args(node::RefNode) = (length(node.args) >= 1)

check_args(node::FuncOpNode) = true


# -- actions (operations with side effects ------------------------------------

type AssignEx <: Action; end

typealias AssignNode Node{AssignEx}

get_lhs(node::AssignNode) = node.args[1]
get_rhs(node::AssignNode) = node.args[2]
get_preevents(node::AssignNode) = node.args[3:end]
function check_args(node::AssignNode) 
    get_lhs(node)::RefNode
    @assert length(node.args) >= 2
    allp(arg->isa(arg, ActionNode), get_preevents(node))
end


# == DAG ======================================================================

typealias SymNodeTable Dict{Symbol,Vector{Symbol}}

type DAG
    value::Node
    bottom_actions::Vector{ActionNode}
    bottom::Node

    symnode_names::SymNodeTable  # kind => used SymNode names
    order::Vector{Node}          # the nodes, topsorted from sources to sinks

#     DAG() = new(NoNode(), ActionNode[], NoNode(), SymNodeTable(), Node[])
    DAG() = new(NoNode(), ActionNode[], NoNode())
end

# __em_node = nothing # debug
# function emit_to_order(dag::DAG, node::Node) # seems to misbehave without ANY
function emit_to_order(dag::DAG, node::ANY)
#     println("emit_to_order:")
#     global __em_node = nothing # debug
#     if is(__em_node, nothing)
#         __em_node = node
#         println("\t",typeof(__em_node))
#     end

    push(dag.order, node)
#     println("\t node.val         = \t", typeof(node.val))
#     println("\t typeof(node)     = \t", typeof(node))
#     println("\t typeof(node.val) = \t", typeof(node.val))
#     println("\t isa(node, SymNode)) =\t", isa(node, SymNode))
#     println("\t isa(node, AssignNode)) =\t", isa(node, AssignNode))
#     println("\t node             = \t", node)    
    if isa(node, SymNode)
        names = @setdefault dag.symnode_names[node.val.kind] Symbol[]
        push(names, node.val.name)
    end
end