
# == Node =====================================================================

abstract Expression
abstract Terminal <: Expression
abstract Operation <: Expression

type Node{T<:Expression}
    val::T
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

typealias TerinalNode Node{Terminal}
typealias EmptyNode Node{EmptyEx}
typealias LiteralNode Node{LiteralEx}
typealias SymNode Node{SymbolEx}

emptynode() = Node(EmptyEx())
litnode(l) = Node(LiteralEx(l))
symnode(name, kind) = Node(SymbolEx(name, kind))

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

callnode(op::Node, args::Vector{Node}) = Node(CallEx(op, args))
refnode(  A::Node, inds::Vector{Node}) = Node(RefEx(  A, inds))


# -- AssignEx -----------------------------------------------------------------

type AssignEx <: Operation
    lhs::RefNode
    rhs::Node
end

typealias AssignNode Node{AssignEx}

assignnode(lhs::RefNode, rhs::Node) = Node(AssignEx(lhs, rhs))
