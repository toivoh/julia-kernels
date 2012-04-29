
load("dag.jl")

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



# == TangleContext ============================================================

typealias SymbolTable Dict{Symbol,Node}

type TangleContext <: Context
    symbols::SymbolTable  # current symbol bindings    
    dag::DAG
end

TangleContext(symbols::SymbolTable) = TangleContext(symbols, DAG())
TangleContext() = TangleContext(SymbolTable())

emit(c::TangleContext, node::Node) = push(c.dag.topsort, node)


# == tangle ===================================================================

function tangle(code)
    context = TangleContext()
    value = tangle(context, code)
    value, context.dag, context
end


#tangle(c::TangleContext, exprs::Vector) = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
function tangle(c::TangleContext, exprs::Vector) 
    nodes = convert(Vector{Node}, [ tangle(c, ex) | ex in exprs ])
    # println("\nnodes = $nodes")
    # println("T=$(typeof(nodes))")
    nodes
end


tangle(c::TangleContext, ex::Any) = LiteralNode(c, ex)   # literal
function tangle(context::TangleContext, name::Symbol)
    @setdefault context.symbols[name] SymNode(context, name, :input)
end
function tangle(context::TangleContext, ex::Expr)
    if ex.head == :line # ignore line numbers
        # don't need to emit this one; shouldn't remain in the DAG
        return EmptyNode() 
    elseif ex.head == :block    # exprs...
        value = Nothing
        for subex in ex.args
            value = tangle(context, subex)
        end
        if is(value, Nothing); return LiteralNode(context, nothing)
        else;                  return value; end
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = tangle_lhs(context, ex.args[1])
        rhs = tangle(context, ex.args[2])
        return entangle_assignment(context, lhs, rhs)
    elseif (ex.head == :call)
        fname = ex.args[1]
        op = @setdefault context.symbols[fname] SymNode(context, fname, :call)
        # println(ex.args[2:end])
        args = tangle(context, ex.args[2:end])
        # println(args)
        return CallNode(context, op, args...)
    elseif (ex.head == :ref)
        args = tangle(context, ex.args)
        # println("args=$args")
        # println("args[2:n]=$(args[2:end])")
        # println("T=$(typeof(args))")
        # args[1]::Node
        # args[2:end]::Vector{Node}
        return RefNode(context, args...)
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- tangle_lhs --------------------------------------------------------------
# Tangle a scalar-valued lhs expr; return lone symbols unadorned

#tangle_lhs(context::TangleContext, name::Symbol) = SymNode(context, name, :local)
tangle_lhs(context::TangleContext, name::Symbol) = name
function tangle_lhs(context::TangleContext, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    oname = ex.args[1]
    output = @setdefault context.symbols[oname] SymNode(context,oname,:output)
    inds = tangle(context, ex.args[2:end])
    RefNode(context, output, inds...)
end


# -- entangle_assignment(context::TangleContext, lhs, rhs) --------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function entangle_assignment(context::TangleContext, lhs::Symbol, rhs::Node) 
    # straight assignment: just store in symbol table
    rhs.name = lhs # remember this alias for rhs
    context.symbols[lhs] = rhs # return rhs
end
function entangle_assignment(context::TangleContext, lhs::RefNode, rhs::Node)
    # indexed assignment to output
    dest = get_A(lhs)::SymNode
    # bind the assignnode to the name of dest
    context.symbols[dest.val.name] = AssignNode(context, lhs, rhs)
    # and evaluate to the rhs
    rhs
end


# == Untangle =================================================================

toexpr(ex::LiteralEx) = ex.value
toexpr(ex::SymbolEx)  = ex.name

toexpr(ex::CallEx, args...)   = expr(:call, args...)
toexpr(ex::RefEx, args...)    = expr(:ref, args...)
toexpr(ex::AssignEx, args...) = expr(:(=), args...)


function untangle(dag::DAG)
    exprs = Any[]
    for node in dag.topsort
        if isa(node, AssignNode)
            ex = untangle(node, true)
            push(exprs, ex)
        elseif !is(node.name, nothing)
            ex = untangle(node, true)
            ex = expr(:(=), node.name, ex)
            push(exprs, ex)
        end
    end
    exprs
end

untangle(nodes::Vector{Node}, fe::Bool) = {untangle(node, fe) | node in nodes}
untangle(node::TerminalNode, force_expand::Bool)  = toexpr(node.val)
function untangle(node::OperationNode, force_expand::Bool)
    if force_expand || is(node.name, nothing)
        return toexpr(node.val, untangle(node.args))
    else
        return node.name
    end
end
untangle(arg) = untangle(arg, false)


# == Some printing ============================================================

function print_list(list::Vector) 
    for item in list; println("\t", item); end
end
function print_dag(dag::DAG) 
    println("nodes (topsort):")
    for node in dag.topsort; println("\t", node); end
end
print_symtable(st::SymbolTable) = (for (k, v) in st; println("\t$k = $v"); end)

function print_context(context::TangleContext) 
    println("Symbols at end:")
    print_symtable(context.symbols)
    println()
    print_dag(context.dag)
end