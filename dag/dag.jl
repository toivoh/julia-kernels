
# dag.jl:
# ======
# Node types for DAG
#

load("utils/req.jl")
req("utils/utils.jl")


abstract Expression

# == Node =====================================================================

type Node{T<:Expression}
    val::T
    args#::Vector{Node} # todo: add back once type inference bug is fixed

    name::Union(Symbol,Nothing)
    num_uses::Int

    # raw Node constructors
    function Node(val::T, args) 
        if !isa(args, Vector{Node});   args = Node[args...];   end

        node = new(val, Node[args...], nothing, 0)
        check_args(node)
        node
    end
    function Node{S<:Expression}(val::S, args...) 
        error("Node{$T}: No constructor for val = $val, args=$args")
    end

    # forwards typealias constructors to Node(T, args...)
    Node(targs...) = Node(T, targs...)
end

Node         {T<:Expression}(val::T, cargs...) = Node{T}(val, cargs...)
function Node{T<:Expression}(node::Node{T}, args) # copy node, but use new args
    newnode = Node(node.val, args)
    newnode.name = node.name
    newnode
end

typealias Nodes Vector{Node}


has_name(node::Node) = !is(node.name, nothing)
get_name(node::Node) = node.name


# == Expressions ==============================================================

## terminals ##
abstract Terminal      <: Expression
type       NoEx        <: Terminal; end
type       LiteralEx   <: Terminal; value; end
type       SymbolEx    <: Terminal; 
    name::Symbol 
    kind::Symbol
    SymbolEx(name::Symbol, kind::Symbol) = new(name, kind)
end

## nonterminals ##
abstract Nonterminal  <: Expression
abstract   Operation  <: Nonterminal # Nonterminal with storable value
abstract     FuncOp   <: Operation     # Operation without side effects
type           KnotEx   <: FuncOp; end   # To encode additional order relations
type           TupleEx  <: FuncOp; end
type           CallEx   <: FuncOp; end
type           RefEx    <: FuncOp; end
abstract     Action   <: Operation     # Operation with side effects
type           AssignEx <: Action; end
type       EllipsisEx   <: Nonterminal; end


## expression comparison ##
# (expression types without fields compare by identity already
isequal(n1::SymbolEx,  n2::SymbolEx) = (n1.name, n1.kind)==(n2.name, n2.kind)
isequal(n1::LiteralEx, n2::LiteralEx) = n1.value==n2.value


# -- Node types ---------------------------------------------------------------

## Node type aliases ##

typealias TerminalNode{T<:Terminal}    Node{T}
typealias NontermNode {T<:Nonterminal} Node{T}
typealias OpNode      {T<:Operation}   Node{T}
typealias FuncOpNode  {T<:FuncOp}      Node{T}
typealias ActionNode  {T<:Action}      Node{T}

typealias NoNode       Node{NoEx}
typealias LiteralNode  Node{LiteralEx}
typealias SymNode      Node{SymbolEx}

typealias CallNode     Node{CallEx}
typealias RefNode      Node{RefEx}
typealias TupleNode    Node{TupleEx}
typealias KnotNode     Node{KnotEx}

typealias EllipsisNode Node{EllipsisEx}
typealias AssignNode   Node{AssignEx}


## Node type dependent methods: constructors, checker, getters ##
 
Node      {T<:Terminal}(::Type{T}, targs...) = Node{T}(T(targs...), ())
check_args{T<:Terminal}(node::Node{T}) = (@expect length(node.args) == 0)

Node      {T<:Nonterminal}(::Type{T}, args...) = Node{T}(T(), args)
get_args  {T<:Nonterminal}(node::Node{T}) = node.args
check_args{T<:Nonterminal}(::Node{T}) = nothing

get_op       (node::CallNode) = node.args[1]
get_callargs (node::CallNode) = node.args[2:end]
check_args   (node::CallNode) = (@expect length(node.args) >= 1)

get_A        (node::RefNode) = node.args[1]
get_inds     (node::RefNode) = node.args[2:end]
check_args   (node::RefNode)  = (@expect length(node.args) >= 1)

check_args(node::KnotNode) = (@expect length(node.args) >= 1)

get_lhs      (node::AssignNode) = node.args[1]
get_rhs      (node::AssignNode) = node.args[2]
get_preevents(node::AssignNode) = node.args[3:end]
function check_args(node::AssignNode) 
    get_lhs(node)::RefNode
    @expect length(node.args) >= 2
    @expect allp(arg->isa(arg, ActionNode), get_preevents(node))
end

