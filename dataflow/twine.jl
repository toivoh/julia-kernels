
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


# == Context ==================================================================

type Context
    symbols::Dict{Symbol,Node}  # current symbol bindings    

    function Context(symbols::Dict{Symbol,Node}) 
        new(symbols, Symbol[], Symbol[], Symbol[], Symbol[])
    end

    inputs ::Vector{Symbol}
    outputs::Vector{Symbol}
    locals ::Vector{Symbol}
    calls  ::Vector{Symbol}
end

function create_symnode(context::Context, name::Symbol, kind::Symbol)
    if has(context.symbols, name)
        error("$name already exists in symbol table")
    end
    node = symnode(name, kind)

    if     kind == :input;   append!(context.inputs,  [name])
    elseif kind == :output;  append!(context.outputs, [name])
    elseif kind == :local;   append!(context.locals,  [name])
    elseif kind == :call;    append!(context.calls,   [name])
    else;                    error("unknown kind of symnode: :$kind");  
    end

    return node
end


# == twine ====================================================================

#twine(c::Context, exprs::Vector) = convert(Vector{Node}, [ twine(c, ex) | ex in exprs ])
function twine(c::Context, exprs::Vector) 
    nodes = convert(Vector{Node}, [ twine(c, ex) | ex in exprs ])
    # println("\nnodes = $nodes")
    # println("T=$(typeof(nodes))")
    nodes
end


twine(::Context, ex::Any) = litnode(ex)   # literal
function twine(context::Context, name::Symbol)
    @setdefault(context.symbols[name], create_symnode(context, name, :input))
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
        return intwine_assignment(context, lhs, rhs)
    elseif (ex.head == :call)
        fname = ex.args[1]
        op = @setdefault(context.symbols[fname],
                         create_symnode(context, fname, :call))
        # println(ex.args[2:end])
        args = twine(context, ex.args[2:end])
        # println(args)
        return callnode(op, args)
    elseif (ex.head == :ref)
        args = twine(context, ex.args)
        # println("args=$args")
        # println("args[2:n]=$(args[2:end])")
        # println("T=$(typeof(args))")
        #refnode(  A::Node, inds::Vector{Node})        
        args[1]::Node
        args[2:end]::Vector{Node}
        return refnode(args[1], args[2:end])
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- twine_lhs --------------------------------------------------------------
# Twine a scalar-valued lhs expr

function twine_lhs(context::Context, name::Symbol)
    @setdefault(context.symbols[name],
                create_symnode(context, name, :local))
end
function twine_lhs(context::Context, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    oname = ex.args[1]
    output = @setdefault(context.symbols[oname],
                         create_symnode(context, oname, :output))
    inds = twine(context, ex.args[2:end])
    refnode(output, inds)
end


# -- intwine_assignment(context::Context, lhs, rhs) ---------------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function intwine_assignment(context::Context, lhs::SymNode, rhs::Node) 
    # straight assignment: just store in symbol table
    context.symbols[lhs.val.name] = rhs # return rhs
end
function intwine_assignment(context::Context, lhs::RefNode, rhs::Node)
    # indexed assignment to output
    dest = (lhs.val.A)::SymNode
    # bind the assignnode to the name of dest
    context.symbols[dest.val.name] = assignnode(lhs, rhs)
    # and evaluate to the rhs
    rhs
end


# == Some printing ============================================================

function print_code(flat_code::Vector) 
    println("code:")
    for ex in flat_code; println("\t", ex); end
end
function print_context(context::Context) 
    println("inputs  = $(context.inputs)")
    println("outputs = $(context.outputs)")
    println("locals  = $(context.locals)")
    println("calls   = $(context.calls)")
    
    println("symbols at end:")
    for (k, v) in context.symbols; println("\t$k = $v"); end
end
