
# dag.jl:
# ======
# Node types for DAG
#

load("utils/utils.jl")
load("utils/prettyprint.jl")


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


# == prettyprinting ===========================================================

pprint_nodeval(io::PrettyIO, node::NoNode) = pprint(io, "NoNode()")
pprint_nodeval(io::PrettyIO, node::LiteralNode) = pprint(io, 
                                             "LiteralNode($(node.val.value))")
pprint_nodeval(io::PrettyIO, node::SymNode) = pprint(io, 
                              "SymNode(:$(node.val.name), :$(node.val.kind))")

repargname(argname, n) = (n == 1 ? [argname] : [argname*string(k) for k=1:n])

get_signature(node::CallNode    ) = ("CallNode"    , [".op", ".arg"])
get_signature(node::RefNode     ) = ("RefNode"     , [".ref",  ".ind"])
get_signature(node::TupleNode   ) = ("TupleNode"   , [".arg"])
get_signature(node::KnotNode    ) = ("KnotNode"    , [
                           repargname(".pre",length(node.args)-1), ".value"])
get_signature(node::EllipsisNode) = ("EllipsisNode", [".arg"])
get_signature(node::AssignNode  ) = ("AssignNode"  , [".lhs", ".rhs", ".dep"])


pprint_nodeval(io::PrettyIO, node::Node) = pprint(io, "Node(", node.val, ")")


function pprint(io::PrettyIO, node::Node)
    if has_name(node)
        pprint(io, get_name(node), " = ")
    end
    if isa(node, TerminalNode)
        pprint_nodeval(io, node)
    else
        name, argnames = get_signature(node)
        numargs = length(node.args)

        dlength = numargs - length(argnames)
        argnames = [argnames[1:end-1], repargname(argnames[end], 1+dlength)]

        new_args_on_next_line::Int = 0
        on_last_arg::Bool=true
        on_first_line::Bool=true
        argindex::Int=1
        function newline_hook()
            ofl, on_first_line = on_first_line, false
            nal, new_args_on_next_line = new_args_on_next_line, 0
            split = (ofl && argindex > 1) ? ":" : (nal >= 2 ? "#" : "+")
            extend = (nal >= 2 ? "=" : "-")
            if nal > 0
                return split*extend*" "
            end            
            return on_last_arg ? "   " : "|  "
        end

        pprint(io, name, "(", " ")
        let io=PrettyChild(io, newline_hook)
            lastverbose = false
            for ((arg, argname), k) in enumerate(zip(node.args, argnames))
                on_last_arg = k==numargs
                argindex = k
                verbose = !has_name(arg)
                if lastverbose || verbose
                    if on_last_arg || verbose || !has_name(node.args[k+1])
                        new_args_on_next_line = 1
                    else 
                        new_args_on_next_line = 2
                    end
                    pprint(io, '\n')
                end
                pprint(io, argname, "=")
                if verbose;  pprint(io, arg);
                else         pprint(io, get_name(arg));  end
                if !on_last_arg
                    pprint(io, ", ")
                end
                lastverbose = verbose
            end
        end
        pprint(io, ")")
    end
end

function pprint_compact(io::PrettyIO, node::Node)
    if has_name(node)
        pprint(io, get_name(node))
    else
        pprint(io, node)
    end
end
