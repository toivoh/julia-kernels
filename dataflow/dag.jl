
# == Node =====================================================================

abstract Expression
abstract Terminal <: Expression
abstract Operation <: Expression

type Node{T<:Expression}
    val::T

    Node(val::T) = new(val)
    Node(args...) = new(T(args...))  # this one is used by the type aliases
end

Node{T}(val::T) = Node{T}(val)


# == DAG ======================================================================

type DAG
    topsort::Vector{Node}

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


# -- invocations --------------------------------------------------------------

type CallEx <: Operation
    op::Node
    args::Vector{Node}
end
type RefEx <: Operation
    A::Node
    inds::Vector{Node}
end

typealias OperationNode Node{Operation}

typealias CallNode Node{CallEx}
typealias RefNode Node{RefEx}


# -- AssignEx -----------------------------------------------------------------

type AssignEx <: Operation
    lhs::RefNode
    rhs::Node
end

typealias AssignNode Node{AssignEx}

assignnode(lhs::RefNode, rhs::Node) = Node(AssignEx(lhs, rhs))
