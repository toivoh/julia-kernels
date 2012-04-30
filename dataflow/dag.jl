
is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))
function expect_expr(ex, head::Symbol)
    if !is_expr(ex, head)
        error("expected expr(:$head,...), found $ex")
    end
end

# macro setdefault(args...)
#     # allow @setdefault(refexpr, default)
#     if (length(args)==1) && is_expr(args[1], :tuple)
#         args = args[1].args
#     end
#     refexpr, default = tuple(args...)
macro setdefault(refexpr, default)
    expect_expr(refexpr, :ref)
    dict_expr, key_expr = tuple(refexpr.args...)
    @gensym dict key #defval
    quote
        ($dict)::Associative = ($dict_expr)
        ($key) = ($key_expr)
        if has(($dict), ($key))
            ($dict)[($key)]
        else
            ($dict)[($key)] = ($default) # returns the newly inserted value
#             ($defval) = ($default)
#             println("defval: ", ($defval))
#             ($dict)[($key)] = ($defval) # returns the newly inserted value
        end
    end
end


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


