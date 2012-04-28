

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
    function Node(val::T, args) 
        node = new(val,args,nothing)
        if !check_args(node)
            error("Invalid node arguments for node type: node = $node")
        end
        node
    end
    Node(val::T) = Node{T}(val, Node[])

    # Used to forward typealias constructors to Node(T, args...)
    Node(c::Context, args...) = Node(c, T, args)
    Node(args...) = Node(T, args)
end

# Node{T}(val::T) = Node{T}(val)

function Node{T<:Expression}(c::Context, ::Type{T}, args::Tuple) 
    node = Node(T, args)
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

Node{T<:Terminal}(::Type{T}, args::Tuple) = Node{T}(T(args...))
check_args{T<:Terminal}(node::Node{T}) = (length(node.args) == 0)


# -- invocations --------------------------------------------------------------

type CallEx <: Operation
end
type RefEx <: Operation
end
type AssignEx <: Operation
end

typealias OperationNode Node{Operation}

typealias CallNode Node{CallEx}
typealias RefNode Node{RefEx}
typealias AssignNode Node{AssignEx}

Node{T<:Operation}(::Type{T}, args) = Node{T}(T(), Node[(args::(Node...))...])

get_op(node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]
check_args(node::CallNode) = (length(node.args) >= 1)

get_A(node::RefNode) = node.args[1]
get_inds(node::RefNode) = node.args[2:end]
check_args(node::RefNode) = (length(node.args) >= 1)

get_lhs(node::AssignNode) = node.args[1]
get_rhs(node::AssignNode) = node.args[2]
check_args(node::AssignNode) = (get_lhs(node)::RefNode; length(node.args) == 2)


