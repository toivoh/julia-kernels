
load("utils.jl")

# type for caching results
typealias ResultsCache Dict{Symbol,Dict}

# type for caching context: should have a field cache::ResultsCache
abstract Context

# context with only cache member
type Cache <: Context
    cache::ResultsCache
    Cache() = new(ResultsCache())
end


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

    # extract argument names tuple for args[2:end]
    restargs = { peel_typeassert(arg) | arg in signature.args[3:end] }
    restargs = expr(:tuple, restargs)

    return_type = (if is_expr(body, doublecolon)
        @expect length(body.args) == 2; body.args[2]
    else; Any; end)

    # create key to identify this method in the cache
    fname = signature.args[1]
    methodkey = quote_expr(gensym(string(fname)))

    # wrap the body with lookup and storage into cache
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
            return cache[restargs]::($return_type)
        end
        
        # evaluate original body, store result and return
        value = let
            ($body)  # ::($return_type) that's where we took it from
        end
        cache[restargs] = value
        value
    end

    # new function definition
    newfun = expr(:function, signature, body)

    # add a check to see that the context argument type <: Context
    context_type_err_msg = strcat("\@cached $signature: first argument should",
        " be of type C <: Context, got ", string(context_decl))
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
