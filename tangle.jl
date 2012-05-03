
# tangle.jl:
# =========
# Convert Julia AST:s to DAG:s in dag.jl format
#

load("dag.jl")


# == TangleContext ============================================================

typealias SymbolTable Dict{Symbol,Node}

type TangleContext
    symbols::SymbolTable  # current symbol bindings
    last_line::Node
    last_actions#::Nodes  # todo: add back once type inference bug is fixed
    dag::DAG # todo: remove!

    TangleContext() = new(SymbolTable(), NoNode(), ActionNode[], DAG())
end

function emit_line(c::TangleContext, node::Node)
    c.last_line = isa(c.last_line, NoNode) ? node : KnotNode(c.last_line, node)
end
function emit_line(c::TangleContext, node::Node, name::Symbol)
    emitted = emit_line(c, node); emitted.name = name
    emitted
end

emit(c::TangleContext, node::Node) = emit(c.dag, node)  # todo: remove!


# == tangle ===================================================================

function tangle(code)
    context = TangleContext()
    value = tangle(context, code)
    if is((value::Node).name, nothing);  value.name = :value;  end
    bottom = KnotNode(context.last_line, context.last_actions..., value)
    context.dag = DAG(bottom) # todo: remove!
#     dag = context.dag
#     set_value!(dag, value)
    value, context.dag, context
end


tangle(c::TangleContext, exps::Vector) = Node[{tangle(c, ex) | ex in exps}...]

tangle(c::TangleContext, ex::Any) = LiteralNode(ex)   # literal
function tangle(c::TangleContext, name::Symbol)
    @setdefault c.symbols[name] SymNode(name, name==:(...) ? :symbol : :input)
end
function tangle(context::TangleContext, ex::Expr)
    if ex.head == :block    # exprs...
        value = LiteralNode(nothing)
        for subex in ex.args;  value = tangle(context, subex);  end

        return value
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = tangle_lhs(context, ex.args[1])
        rhs = tangle(context, ex.args[2])

        return entangle_assignment(context, lhs, rhs)
    elseif ex.head == :call
        fname = ex.args[1]
        op = @setdefault context.symbols[fname] SymNode(fname, :call)
        args = tangle(context, ex.args[2:end])

        return CallNode(op, args...)
    elseif ex.head == :ref;   return RefNode(tangle(context, ex.args)...)
    # todo: test!:
    elseif ex.head == :(...); return EllipsisNode(tangle(context, ex.args)...)
    # todo: test!:
    elseif ex.head == :tuple; return TupleNode(tangle(context, ex.args)...)
    elseif ex.head == :line;  return NoNode() # ignore line numbers
    end
    error("unexpected scalar rhs: ex = $ex")
end

# -- tangle_lhs --------------------------------------------------------------
# Tangle a scalar-valued lhs expr; return lone symbols unadorned

tangle_lhs(context::TangleContext, name::Symbol) = name
function tangle_lhs(context::TangleContext, ex::Expr)
    # lvalue for indexed assignment
    @expect is_expr(ex, :ref)
    oname = ex.args[1]
    output = @setdefault context.symbols[oname] SymNode(oname, :output)
    inds = tangle(context, ex.args[2:end])
    RefNode(output, inds...)
end


# -- entangle_assignment(context::TangleContext, lhs, rhs) --------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function entangle_assignment(context::TangleContext, dest::Symbol, rhs::Node) 
    # straight assignment: just store in symbol table
    context.symbols[dest] = emit_line(context, rhs, dest) # return rhs
end
function entangle_assignment(context::TangleContext, lhs::RefNode, rhs::Node)
    # Indexed assignment to output
    dest = get_A(lhs)::SymNode
    node = AssignNode(lhs, rhs, context.last_actions...)
    #     bind the AssignNode to the name of dest
    context.symbols[dest.val.name] = emit_line(context, node)
    context.last_actions = [node]
    rhs # and evaluate to the rhs
end


# == Untangle =================================================================

toexpr(ex::LiteralEx) = ex.value
toexpr(ex::SymbolEx)  = ex.name

toexpr(ex::CallEx,     args...) = expr(:call,  args...)
toexpr(ex::RefEx,      args...) = expr(:ref,   args...)
toexpr(ex::TupleEx,    args...) = expr(:tuple, args...)
toexpr(ex::EllipsisEx, args...) = expr(:(...), args...)

toexpr(ex::AssignEx,   args...) = expr(:(=), args[1:2]...)# remove dependencies


function untangled(dag::DAG)
    exprs = Any[]
    for node in dag.order
        if isa(node, AssignNode)
            ex = untangled(node, true)
            push(exprs, ex)
        elseif !is(node.name, nothing)
            ex = untangled(node, true)
            ex = expr(:(=), node.name, ex)
            push(exprs, ex)
        end
    end
    value = get_value(dag)
    if !is(dag.order[end], value)
        push(exprs, value.name)
    end
    exprs
end

untangled(nodes::Nodes, fe::Bool) = {untangled(node, fe) | node in nodes}
untangled(node::TerminalNode, force_expand::Bool)  = toexpr(node.val)
function untangled(node::NontermNode, force_expand::Bool)
    if force_expand || is(node.name, nothing)
        return toexpr(node.val, untangled(node.args)...)
    else
        return node.name
    end
end
untangled(node::KnotNode, fe::Bool) = untangled(node.args[end])
untangled(arg) = untangled(arg, false)


# == Some printing ============================================================

function print_list(list::Vector) 
    for item in list; println("\t", item); end
end
function print_dag(dag::DAG) 
    println("nodes:")
    for node in dag.order; println("\t", node); end
end
print_symtable(st::SymbolTable) = (for (k, v) in st; println("\t$k = $v"); end)

function print_context(context::TangleContext) 
    println()
    print_dag(context.dag) 
    println("Symbols at end:")
    print_symtable(context.symbols)
    println("SymNode names by kind:")
    for (k, names) in context.dag.symnode_names; println("\t$k:\t$names"); end 
end

print_untangled(dag::DAG) = (order!(dag); print_list(untangled(dag)))
