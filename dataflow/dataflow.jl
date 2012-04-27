
function is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))
function expect_expr(ex, head::Symbol)
    if !is_expr(ex, head)
        error("expected expr(:$head,...), found $ex")
    end
end

macro getdefault(args...)
    # allow @getdefault(refexpr, default)
    if (length(args)==1) && is_expr(args[1], :tuple)
        args = args.args
    end
    refexpr, default = args

    expect_expr(ex, :ref)
    dict_expr, key_expr = ex.args
    @gensym dict, key
    quote
        $dict::Associative = $dict_expr
        $key = $key_expr
        if has($dict, $key)
            $dict[$key]
        else
            $defualt
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

emptynode() = Node(EmptyOp)
litnode(l) = Node(LiteralOp(l))
symnode(name, kind) = Node(SymbolOp(name, kind))

typealias EmptyNode Node{EmptyOp}
typealias LiteralNode Node{LiteralOp}
typealias SymNode Node{SymbolOp}

# -- invocations --------------------------------------------------------------

type CallOp <: Invocation
    op::Node
    args::Vector{Node}
end
type RefOp <: Invocation
    A::Node
    inds::Vector{Node}
end


# == Context ==================================================================

type Context
    symbols::HashTable{Symbol,Node}  # current symbol bindings    

    function Context(symbols::HashTable{Symbol,Node) 
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
    context.symbols[name] = node

    if     kind == :input;   append!(context.inputs,  [name])
    elseif kind == :output;  append!(context.outputs, [name])
    else;                    error("unknown argument kind: :$kind");  
    end

    return node
end


# == reconnect ================================================================

reconnect(::Context, ex::Any) = LiteralOp(ex)   # literal
function reconnect(context::Context, name::Symbol)
    @getdefault context.symbols[name] create_unbound(context, :input, name)
end
function reconnect(context::Context, ex::Expr)
    if ex.head == :line # ignore line numbers
        return emptynode()
    elseif ex.head == :block    # exprs...
        value = litnode(nothing)
        for subex in ex.args
            value = reconnect(context, subex)
        end
        return value
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = reconnect_lhs(context, ex.args[1])
        rhs = reconnect(context, ex.args[2])        
        return connect_assignment(context, lhs, rhs)
    elseif (ex.head == :call)
        fname = ex.args[1]
        op = @getdefault(context.symbols[name], 
                         create_unbound(context, :function, name))
        args = reconnect(context, ex.args[2:end])
        return callnode(ex.args[1], args)
    elseif (ex.head == :ref)
        args = reconnect(context, ex.args)
        return refnode(args)
    end
    error("unexpected scalar rhs: ex = $ex")
end


