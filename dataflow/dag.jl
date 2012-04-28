

abstract Context

# == Node =====================================================================

abstract Expression
abstract Terminal <: Expression
abstract Operation <: Expression

type Node{T<:Expression}
    val::T
    args::Vector{Node}

    name::Union(Symbol,Nothing)

    Node(val::T, args) = new(val,args,nothing)
    Node(c::Context, args...) = Node(T, c, args)
    Node(args...) = Node(T, args...)
end

# Node{T}(val::T) = Node{T}(val)

function Node{T<:Expression}(::Type{T}, c::Context, args) 
    node = Node(T, args...)
    emit(c, node)
    node
end


# == DAG ======================================================================

type DAG
    topsort::Vector{Node}  # the nodes, topsorted from sources to sinks

    DAG() = new(Node[])
    DAG(topsort) = new(topsort)
end


# -- terminals ----------------------------------------------------------------

type EmptyEx <: Terminal
end
type LiteralEx <: Terminal
    value
end
type SymbolEx <: Terminal
    name::Symbol
    kind::Symbol

    SymbolEx(name::Symbol, kind::Symbol) = new(name, kind)
end

typealias TerminalNode Node{Terminal}

typealias EmptyNode Node{EmptyEx}
typealias LiteralNode Node{LiteralEx}
typealias SymNode Node{SymbolEx}

Node{T<:Terminal}(::Type{T}, args...) = Node{T}(T(args...),Node[])


# -- invocations --------------------------------------------------------------

type CallEx <: Operation
end
type RefEx <: Operation
end

typealias OperationNode Node{Operation}

typealias CallNode Node{CallEx}
typealias RefNode Node{RefEx}

function Node(::Type{CallEx}, op::Node, callargs::Vector{Node})
    CallNode(CallEx(), Node[op, callargs...])
end
get_op(node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]

function Node(::Type{RefEx}, A::Node, inds::Vector{Node})
    RefNode(RefEx(), Node[A, inds...])
end
get_A(node::RefNode) = node.args[1]
get_inds(node::RefNode) = node.args[2:end]


# -- AssignEx -----------------------------------------------------------------

type AssignEx <: Operation
end

typealias AssignNode Node{AssignEx}

function Node(::Type{AssignEx}, lhs::RefNode, rhs::Node)
    AssignNode(AssignEx(), Node[lhs, rhs])
end
get_lhs(node::AssignNode) = node.args[1]
get_rhs(node::AssignNode) = node.args[2]
