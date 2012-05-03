
load("utils/utils.jl")


# == Node =====================================================================

abstract Expression

type Node{T<:Expression}
    val::T
#    args::Vector{Node}
    args

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

    # Used to forward typealias constructors to Node(T, args...)
#    Node(targs...) = Node(T, targs...)
    function Node(targs...)
        #println("Node{$T}($targs)")
        Node(T, targs...)
    end
end

Node{T<:Expression}(val::T, cargs...) = Node{T}(val, cargs...)

function Node{T<:Expression}(node::Node{T}, args) 
    newnode = Node(node.val, args)
    newnode.name = node.name
    newnode
end

typealias Nodes Vector{Node}


# -- expressions --------------------------------------------------------------

abstract Terminal      <: Expression
type       NoEx        <: Terminal; end
type       LiteralEx   <: Terminal; value; end
type       SymbolEx    <: Terminal; 
    name::Symbol 
    kind::Symbol
    SymbolEx(name::Symbol, kind::Symbol) = new(name, kind)
end

abstract Nonterminal   <: Expression
abstract   Operation   <: Nonterminal # Nonterminal with storable value
abstract     FuncOp    <: Operation     # Operation without side effects
abstract       GroupOp <: FuncOp          # FuncOp with all arguments as peers
type             TupleEx <: GroupOp; end
type             KnotEx  <: GroupOp; end    # To encode additional order rels.
type           CallEx    <: FuncOp;  end
type           RefEx     <: FuncOp;  end
abstract     Action    <: Operation     # Operation with side effects
type           AssignEx <: Action;   end
type       EllipsisEx    <: Nonterminal; end

typealias TerminalNode{T<:Terminal}    Node{T}
typealias NontermNode {T<:Nonterminal} Node{T}
typealias OpNode      {T<:Operation}   Node{T}
typealias FuncOpNode  {T<:FuncOp}      Node{T}
typealias GroupOpNode {T<:GroupOp}     Node{T}
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


Node      {T<:Terminal}(::Type{T}, targs...) = Node{T}(T(targs...), ())
check_args{T<:Terminal}(node::Node{T}) = (@expect length(node.args) == 0)

Node      {T<:Nonterminal}(::Type{T}, args...) = Node{T}(T(), args)
get_args  {T<:Nonterminal}(node::Node{T}) = node.args
check_args{T<:Nonterminal}(::Node{T}) = nothing


get_op      (node::CallNode) = node.args[1]
get_callargs(node::CallNode) = node.args[2:end]
check_args  (node::CallNode) = (@expect length(node.args) >= 1)

get_A     (node::RefNode) = node.args[1]
get_inds  (node::RefNode) = node.args[2:end]
check_args(node::RefNode)  = (@expect length(node.args) >= 1)

check_args(node::KnotNode) = (@expect length(node.args) >= 1)

get_lhs      (node::AssignNode) = node.args[1]
get_rhs      (node::AssignNode) = node.args[2]
get_preevents(node::AssignNode) = node.args[3:end]
function check_args(node::AssignNode) 
    get_lhs(node)::RefNode
    @expect length(node.args) >= 2
    @expect allp(arg->isa(arg, ActionNode), get_preevents(node))
end


# == DAG ======================================================================

typealias SymNodeTable Dict{Symbol,Vector{Symbol}}

type DAG
    bottom_actions::Vector{ActionNode}
    bottom::Node

    symnode_names::SymNodeTable  # kind => used SymNode names
    order::Nodes                 # the nodes, topsorted from sources to sinks

#     DAG() = new(ActionNode[], NoNode(), SymNodeTable(), Node[])
    DAG() = new(ActionNode[], NoNode())
    
    DAG(bottom::Node) = new(bottom.args[1:end-1], bottom)
end

function set_value!(dag::DAG, value::Node)
    dag.bottom = TupleNode(dag.bottom_actions..., value)
end

get_value(dag::DAG) = dag.bottom.args[end]

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
