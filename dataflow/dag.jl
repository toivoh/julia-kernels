

abstract Context

# == Node =====================================================================

abstract Expression
abstract Terminal <: Expression
abstract Operation <: Expression

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
    Node(c::Context, args...) = Node(c, T, args...)
    Node(args...) = Node(T, args...)
end

Node{T}(val::T, args...) = Node{T}(val, args...)

function Node{T<:Expression}(c::Context, ::Type{T}, args...) 
    node = Node(T, args...)
    emit(c, node)
    node
end


# == ODAG =====================================================================

type ODAG
    order::Vector{Node}  # the nodes, topsorted from sources to sinks

    ODAG() = new(Node[])
    ODAG(order) = new(order)
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

typealias TerminalNode{T<:Terminal} Node{T}

typealias EmptyNode Node{EmptyEx}
typealias LiteralNode Node{LiteralEx}
typealias SymNode Node{SymbolEx}

Node{T<:Terminal}(::Type{T}, args...) = Node{T}(T(args...))
check_args{T<:Terminal}(node::Node{T}) = (length(node.args) == 0)


# -- invocations --------------------------------------------------------------

type CallEx <: Operation
end
type RefEx <: Operation
end
type AssignEx <: Operation
end

typealias OperationNode{T<:Operation} Node{T}

typealias CallNode Node{CallEx}
typealias RefNode Node{RefEx}
typealias AssignNode Node{AssignEx}

Node{T<:Operation}(::Type{T}, args...) = Node{T}(T(), args...)

get_op(node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]
check_args(node::CallNode) = (length(node.args) >= 1)

get_A(node::RefNode) = node.args[1]
get_inds(node::RefNode) = node.args[2:end]
check_args(node::RefNode) = (length(node.args) >= 1)

get_lhs(node::AssignNode) = node.args[1]
get_rhs(node::AssignNode) = node.args[2]
check_args(node::AssignNode) = (get_lhs(node)::RefNode; length(node.args) == 2)


