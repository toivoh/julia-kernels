
quote_expr(ex) = expr(:quote, ex)

is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))

macro expect(args...)
    if !(1 <= length(args) <= 2)
        error("\n@expect: expected one or two arguments")
    end
    predicate = args[1]
    if length(args) >= 2
        message = args[2]

        if is_expr(message, :tuple)
            msg_parts = message.args
        else
            msg_parts = {message}
        end
    else
        msg_parts = {"Expected: ", string(predicate)}
    end    
    :($predicate ? nothing : $(expr(:call, :error, msg_parts...)))
end

macro show(ex)
    :(println(($string(ex)), " = ", $ex) )
end

function expect_expr(ex, head::Symbol)
    @expect is_expr(ex, head) "expected expr(:$head,...), found $ex"
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
typealias Cache Dict{Symbol,Dict}

const doublecolon = @eval (:(x::Int)).head

peel_typeassert(ex::Symbol) = ex
function peel_typeassert(ex::Expr)
    @expect ((ex.head == doublecolon) && length(ex.args) == 2) (
        "expected variable declaration, got $ex")
    return (ex.args[1])::Symbol
end
peel_typeassert(x::Any) = error("expected variable declaration, got $x")

function wrap_cached(func::Expr)
    # extract signature and body
    if (func.head == :function) || (func.head == :(=))
        signature = func.args[1]
        body = func.args[2]
    else
        error("\n@cached: don't know how to handle func.head = $(func.head)")
    end
    @expect is_expr(signature, :call) (
        "\n@cached: don't know how to handle signature = $signature")
    @expect length(signature.args) >= 2 (
        "\n@cached $signature: need a first argument (of type C <: Context")

    # split first argument (context) into name and type
    context_decl = signature.args[2]
    @expect is_expr(context_decl, doublecolon) ("\n@cached $signature: ",
        "first argument should be of type C <: Context, got ", context_decl)
    context = peel_typeassert(context_decl)
    context_type = context_decl.args[2]

    restargs = { peel_typeassert(arg) | arg in signature.args[3:end] }
    restargs = expr(:tuple, restargs)

    fname = signature.args[1]
    methodkey = quote_expr(gensym(string(fname)))

    body = quote
        # find result cache for this method in context
        mcache = ($context).cache
        if !has(mcache, ($methodkey))
            mcache[($methodkey)] = Dict()
        end
        cache = mcache[($methodkey)]

        # return cached result if available
        restargs = ($restargs)
        if has(cache, restargs)
            return cache[restargs]
        end
        
        # evaluate original body, store result and return
        value = let
            ($body)
        end
        cache[restargs] = value
        value
    end

    newfun = expr(:function, signature, body)

    context_type_err_msg = strcat("\@cached $signature: first argument should be ",
        "of type C <: Context, got ",
        string(context_decl))
    quote
        if !($context_type <: $Context)
            error($context_type_err_msg)
        end
        $newfun
    end
end

macro cached(func)
    wrap_cached(func)
end
