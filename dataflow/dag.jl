
load("utils.jl")


abstract Context

# == Node =====================================================================

abstract Expression
abstract Terminal  <: Expression
abstract Operation <: Expression
abstract FuncOp        <: Operation # operation without side effects
abstract Action        <: Operation # operation with side effects

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
    Node(c::Context, targs...) = Node(c, T, targs...)
    Node(targs...) = Node(T, targs...)
end

Node{T}(val::T, args...) = Node{T}(val, args...)

function Node{T<:Expression}(c::Context, ::Type{T}, targs...) 
    node = Node(T, targs...)
    emit(c, node)
    node
end


typealias TerminalNode{T<:Terminal} Node{T}

typealias OpNode{T<:Operation}  Node{T}
typealias FuncOpNode{T<:FuncOp} Node{T}
typealias ActionNode{T<:Action} Node{T}


# == ODAG =====================================================================

type ODAG
    order::Vector{Node}  # the nodes, topsorted from sources to sinks

    symnode_names::Dict{Symbol,Vector{Symbol}}  # kind => used SymNode names

    ODAG() = new(Node[], Dict{Symbol,Vector{Symbol}}())
    ODAG(order) = new(order)
end

function emit(dag::ODAG, node::Node)
    push(dag.order, node)
    if isa(node, SymNode)
        names = @setdefault dag.symnode_names[node.val.kind] Symbol[]
        push(names, node.val.name)
    end
end


# -- terminals ----------------------------------------------------------------

type EmptyEx <: Terminal; end
type LiteralEx <: Terminal
    value
end
type SymbolEx <: Terminal
    name::Symbol
    kind::Symbol

    SymbolEx(name::Symbol, kind::Symbol) = new(name, kind)
end

typealias EmptyNode Node{EmptyEx}
typealias LiteralNode Node{LiteralEx}
typealias SymNode Node{SymbolEx}

Node{T<:Terminal}(::Type{T}, targs...) = Node{T}(T(targs...))
check_args{T<:Terminal}(node::Node{T}) = (length(node.args) == 0)


# -- functional operations (side effect free) ---------------------------------

type CallEx     <: Operation; end
type RefEx      <: Operation; end
type EllipsisEx <: Operation; end

typealias CallNode     Node{CallEx}
typealias RefNode      Node{RefEx}
typealias EllipsisNode Node{RefEx}

Node{T<:Operation}(::Type{T}, args...) = Node{T}(T(), args...)

get_op(node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]
check_args(node::CallNode) = (length(node.args) >= 1)

get_A(node::RefNode) = node.args[1]
get_inds(node::RefNode) = node.args[2:end]
check_args(node::RefNode) = (length(node.args) >= 1)

check_args(node::EllipsisNode) = true


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


