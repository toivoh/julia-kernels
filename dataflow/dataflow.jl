
is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))
function expect_expr(ex, head::Symbol)
    if !is_expr(ex, head)
        error("expected expr(:$head,...), found $ex")
    end
end

macro setdefault(args...)
    # allow @setdefault(refexpr, default)
    if (length(args)==1) && is_expr(args[1], :tuple)
        args = args[1].args
    end
    refexpr, default = tuple(args...)

    expect_expr(refexpr, :ref)
    dict_expr, key_expr = tuple(refexpr.args...)
    @gensym dict key

    quote
        ($dict)::Associative = ($dict_expr)
        ($key) = ($key_expr)
        if has(($dict), ($key))
            ($dict)[($key)]
        else
            ($dict)[($key)] = ($default) # returns the newly inserted value
        end
    end
end


# == Node =====================================================================

abstract Operation
abstract Terminal <: Operation
abstract Invocation <: Operation

type Node{T<:Operation}
    op::T
end

# -- terminals ----------------------------------------------------------------

type EmptyOp <: Terminal
end
type LiteralOp <: Terminal
    value
end
type SymbolOp <: Terminal
    name::Symbol
    kind::Symbol

    SymbolOp(name::Symbol, kind::Symbol) = new(name, kind)
end

typealias TerinalNode Node{Terminal}
typealias EmptyNode Node{EmptyOp}
typealias LiteralNode Node{LiteralOp}
typealias SymNode Node{SymbolOp}

emptynode() = Node(EmptyOp)
litnode(l) = Node(LiteralOp(l))
symnode(name, kind) = Node(SymbolOp(name, kind))

# -- invocations --------------------------------------------------------------

type CallOp <: Invocation
    op::Node
    args::Vector{Node}
end
type RefOp <: Invocation
    A::Node
    inds::Vector{Node}
end

typealias InvocationNode Node{Invocation}
typealias CallNode Node{CallOp}
typealias RefNode Node{RefOp}

callnode(op::Node, args::Vector{Node}) = Node(CallOp(op, args))
refnode(  A::Node, inds::Vector{Node}) = Node(RefOp(  A, inds))


# -- AssignOp -----------------------------------------------------------------

type AssignOp <: Operation
    lhs::RefNode
    rhs::Node
end

typealias AssignNode Node{AssignOp}

assignnode(lhs::RefNode, rhs::Node) = Node(AssignOp(lhs, rhs))


# == Context ==================================================================

type Context
    symbols::HashTable{Symbol,Node}  # current symbol bindings    

    function Context(symbols::HashTable{Symbol},Node) 
        new(symbols, Symbol[], Symbol[])
    end

    inputs::Vector{Symbol}
    outputs::Vector{Symbol}
end

function create_unbound(context::Context, name::Symbol, kind::Symbol)
    if has(context.symbols, name)
        error("$name already exists in symbol table")
    end
    node = symnode(name, kind)

    if     kind == :input;   append!(context.inputs,  [name])
    elseif kind == :output;  append!(context.outputs, [name])
    else;                    error("unknown argument kind: :$kind");  
    end

    return node
end


# == twine ====================================================================

twine(::Context, ex::Any) = LiteralOp(ex)   # literal
function twine(context::Context, name::Symbol)
    @setdefault(context.symbols[name], create_unbound(context, :input, name))
end
function twine(context::Context, ex::Expr)
    if ex.head == :line # ignore line numbers
        return emptynode()
    elseif ex.head == :block    # exprs...
        value = litnode(nothing)
        for subex in ex.args
            value = twine(context, subex)
        end
        return value
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = twine_lhs(context, ex.args[1])
        rhs = twine(context, ex.args[2])        
        return lace_assignment(context, lhs, rhs)
    elseif (ex.head == :call)
        fname = ex.args[1]
        op = @setdefault(context.symbols[name],
                         create_unbound(context, :function, name))
        args = twine(context, ex.args[2:end])
        return callnode(ex.args[1], args)
    elseif (ex.head == :ref)
        args = twine(context, ex.args)
        return refnode(args)
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- twine_lhs --------------------------------------------------------------
# Twine a scalar-valued lhs expr

function twine_lhs(context::Context, name::Symbol)
    @setdefault(context.symbols[name],
                create_unbound(context, :output, name))
end
function twine_lhs(context::Context, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    output = expect_argument(:output, context, ex.args[1])
    inds = twine(context, ex.args[2:end])
    return expr(:ref, output, inds...)
end


# -- lace_assignment(context::Context, lhs, rhs) ------------------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function lace_assignment(context::Context, lhs::SymNode, rhs::Node) 
    # straight assignment: just store in symbol table
    context.symbols[lhs] = rhs # return rhs
end
function lace_assignment(context::Context, lhs::RefNode, rhs::Node)
    # indexed assignment to output
    dest = (lhs.op.A)::SymNode
    # bind the assignnode to the name of dest
    context.symbols[dest.name] = assignnode(lhs, rhs)
    # and evaluate to the rhs
    rhs
end

