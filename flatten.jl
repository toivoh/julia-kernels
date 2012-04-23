
# == Context ==================================================================

type SymEntry
    value
    kind::Symbol
    wrapped

    SymEntry(value, kind::Symbol) = new(value, kind, nothing)
end

type Context
    symbols::HashTable{Symbol,SymEntry}  # current symbol bindings    
    emit_function::Function              # sink for emitted instructions

    function Context(symbols::HashTable{Symbol,SymEntry}, emit) 
        new(symbols, emit, Symbol[], Symbol[])
    end

    inputs::Vector{Symbol}
    outputs::Vector{Symbol}
end

emit(c::Context, ex) = c.emit_function(ex)

function create_argument(kind::Symbol, context::Context, name::Symbol)
    if has(context.symbols, name)
        error("$name already exists in symbol table")
    end
    context.symbols[name] = SymEntry(name, kind)

    if     kind == :input;   append!(context.inputs,  [name])
    elseif kind == :output;  append!(context.outputs, [name])
    else;                    error("unknown argument kind: :$kind");  
    end

    return name
end


# == Flatten ==================================================================

function expect_expr(ex, head::Symbol)
    if !isa(ex, Expr) || (ex.head != head)
        error("expected expr(:$head,...), found $ex")
    end
end


# -- expect_argument(kind, ...) -----------------------------------------------
# Try to extract and return an input/output (depending on kind) from name.
# If it's unbound, create one and return.
# If it exists and is of the wrong kind, throw an error.

function expect_argument(kind::Symbol, context::Context, name::Symbol)
    if has(context.symbols, name)
        entry = context.symbols[name]
        if entry.kind != kind
            error("expected $kind, found $entry")
        end
        return entry.value
    else
        return create_argument(kind, context, name)
    end
end


# -- flatten ------------------------------------------------------------------
# Flatten a scalar-valued rhs expr
# Returns the expr's value as a scalar var symbol

flatten(c::Context, exprs::Vector) = { flatten(c, ex) | ex in exprs }

function wrap_input(c::Context, name) 
    entry = c.symbols[name]
    if entry.wrapped == nothing
        entry.wrapped = flatten(context, expr(:call, :readinput, name))
    end
    return entry.wrapped
end

flatten(c::Context, ex::Any) = ex   # literal
function flatten(context::Context, name::Symbol)
    if has(context.symbols, name)
        entry = context.symbols[name]
        if entry.kind == :local
            return entry.value
        elseif entry.kind == :input
            return wrap_input(context, entry.value)
        else
            error("expected local/input, got $entry")
        end
    else
        # new input
        return wrap_input(context, create_argument(:input, context, name))
    end
end
function flatten(context::Context, ex::Expr)
    if ex.head == :line # ignore line numbers
        return nothing # CONSIDER: could this shadow the last actual value?
    elseif ex.head == :block    # exprs...
        value = nothing
        for subex in ex.args
            value = flatten(context, subex)
        end
        return value
    elseif ex.head == :(=)  # assignment: lvalue = expr
        lhs = flatten_lhs(context, ex.args[1])
        rhs = flatten(context, ex.args[2])
        return execute_assignment(context, lhs, rhs)
    elseif (ex.head == :call) || (ex.head == :ref) # :call(op, exprs...)
                                                   # :ref(input, exprs...)
        node = flatten_callref(context, ex)
        target = gensym()
        emit(context, expr(:(=), target, node))
        return target
    end
    error("unexpected scalar rhs: ex = $ex")
end


# -- flatten_callref ----------------------------------------------------------
# Flatten a scalar rhs :call / :ref expr
# Returns primivite expr with symbol-only arguments

function flatten_callref(context::Context, ex::Expr)
    if ex.head == :call
        op = ex.args[1]
        if op == :readinput
            args = {expect_argument(:input, context, ex.args[2])}
        else
            args = flatten(context, ex.args[2:end])
        end
        return expr(ex.head, op, args...)
    elseif ex.head == :ref
        input = expect_argument(:input, context, ex.args[1])
        inds = flatten(context, ex.args[2:end])
        return expr(ex.head, input, inds...)
    end
end


# -- flatten_lhs --------------------------------------------------------------
# Flatten a scalar-valued lhs expr
# Returns the lhs as a symbol / :ref expr

flatten_lhs(context::Context, name::Symbol) = name # scalar var
function flatten_lhs(context::Context, ex::Expr)
    # assign[]
    expect_expr(ex, :ref)
    output = expect_argument(:output, context, ex.args[1])
    inds = flatten(context, ex.args[2:end])
    return expr(:ref, output, inds...)
end


# -- execute_assignment(context::Context, lhs, rhs) ---------------------------
# Process assignment lhs = rhs.
# Returns value = rhs 

function execute_assignment(context::Context, lhs::Symbol, rhs::Symbol) 
    # straight assignment: just store in symbol table
    context.symbols[lhs] = SymEntry(rhs, :local)
    rhs
end
function execute_assignment(context::Context, lhs::Expr, rhs::Symbol)
    # indexed assignment to output
    emit(context, expr(:(=), lhs, rhs))
    rhs
end


# -- Test code ----------------------------------------------------------------

code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
end

symbols = HashTable{Symbol,SymEntry}()
flat_code = {}
receive = ex->append!(flat_code, {ex})
context = Context(symbols, receive)

value = flatten(context, code)

println("code:")
for ex in flat_code; println("\t", ex); end

println("value = $value")
println("inputs  = $(context.inputs)")
println("outputs = $(context.outputs)")

println("symbols at end:")
for (k, v) in context.symbols
    println("\t$k = $v")
end
