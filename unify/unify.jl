
load("utils/req.jl")
req("utils/utils.jl")


# == pattern types ============================================================

abstract Pattern # Patterns that can match a different type than their own
abstract Typed{T} <: Pattern # Patterns that match only values of type T

# need these:?
valtype{T}(::Typed{T}) = T
# valtype(::Unyped) = Any

 # Pattern that matches all values of type T
type TypePattern{T} <: Typed{T}; end
typealias Universal TypePattern{Any}
typealias Unpattern TypePattern{None}

# Return a pattern that matches any value of type T
match(T) = TypePattern{T}()

const anyvalue  = match(Any)   # The pattern that matches anything
const nonevalue = match(None)  # The pattern that matches nothing

show(io::IO, ::Universal) = print(io, "anyvalue")
show(io::IO, ::Unpattern) = print(io, "nonevalue")
show{T}(io::IO, p::TypePattern{T}) = print(io, "match($T)")

# pattern variable, compares by identity
type PVar <: Pattern
    name::Symbol
end

# A typed pattern variable
type TVar{T} <: Typed{T}
    X::PVar

    # Makes sure to return
    #  * nonevalue instead of ::TVar{None}
    #  * X::PVar itself instead of ::TVar{Any}
    TVar(X::PVar) = is(T, None) ? nonevalue : (is(T,Any) ? X : new(X))
end

pvar(name::Symbol) = PVar(name)
pvar(T, name::Symbol) = TVar{T}(PVar(name))
pvar(T, X::PVar) = TVar{T}(X)
pvar(names::(Symbol...)) = map(pvar, names)

show(io::IO, p::PVar) = print(io, "pvar(:$(p.name))")
show{T}(io::IO, p::TVar{T}) = print(io, "pvar($T,:$(p.X.name))")

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    # todo: allow syntax @pvar X::Int ?
    quoted_args = {quoted_expr(a) for a in args}
    quote
       ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
    end
end

# return the untyped value held inside p::Typed
# (though anyvalue is nominally typed)
get_p( ::TypePattern) = anyvalue
get_p(p::TVar) = p.X


# -- restrict --------------------------------------------------------- 

# restrict(T, x): 
# Return the restriction of the pattern x to value type T
restrict(::Type{Any}, x)              = x
restrict(::Type{Any}, x::TypePattern) = x
restrict(::Type{Any}, x::TVar)        = x
restrict(::Type{Any}, x::PVar)        = x

restrict(::Type{None}, ::Any)         = nonevalue
restrict(::Type{None}, ::TypePattern) = nonevalue
restrict(::Type{None}, ::TVar)        = nonevalue
restrict(::Type{None}, ::PVar)        = nonevalue

restrict(T, p::PVar) = TVar{T}(p)
restrict{T}(R, t::TypePattern{T}) = TypePattern{tintersect(R,T)}()
restrict{T}(R, t::TVar{T}) = restrict(tintersect(R,T), t.X)
restrict(T, x) = isa(x, T) ? x : nonevalue  # for non-Patterns


# == Matching =================================================================

type Matching
    d::Dict{PVar,Any}
    Matching() = new(Dict{PVar,Any}())
end

type Unfinished; end
const unfinished = Unfinished();

expand(m::Matching,  ::PVar,::TypePattern) = error("TypePattern:s should "*
                                                   "never be stored in m.d")
# circular dependency ==> no finite pattern matches
expand(m::Matching, X::PVar,::Unfinished) = (m.d[X] = nonevalue)

function expand(m::Matching, x)
    @assert !is(x,X)    # should never store X=X
    if isa(x, TVar) && (is(x.X,X)); return x; end

    m.d[X] = unfinished
    x = m[x]             # look up x
    return m.d[X] = x    # store and return
end

function ref(m::Matching, X::PVar)
    if has(m.d, X)
        x = m.d[X]
        return expand(m, X,x)
    else
        return X
    end
end

# Add the constraint X==y in m, 
# and return the unification of X and y given m
function meet(m::Matching, X::PVar,y)
#    x = get(m.d, X, X)          # default: implicit binding X := X
#     if isa(y,PVar)  # if y is a variable: look it up. multiple times?
#         y = get(m.d, y, y)
#     elseif isa(y,TVar) && has(m.d, y.X)
#         y = restrict(valuetype(y), m[y])
#     end
    x = m[X]
    if is(x,X)
        if isa(y, TypePattern)
            z = restrict(valtype(y), X)
        else
            z = y
        end
    else
        z = unify(m, x,y)      # unify with previous binding
    end
    if is(z,X); return X; end # don't bother to bind X := X
    return m.d[X] = z           # return new binding
end


# == unify ====================================================================

# (@retnaught x) returns nonevalue from the function if x is nonevalue;
# evaluates to x otherwise.
macro retnaught(ex)
    @gensym p
    quote
        ($p) = ($ex)
        if is(($p), nonevalue);  return nonevalue;  end
        ($p)
    end
end

# unify(m::Matching, x, y)
# -----------------------
# Find the bindings needed to make the patterns x==y,
# (along with the ones already present in b), 
# and store them in b.
# Return the unification z = (x given b) = (y given b),
# or nonevalue if the match is not possible.

# unify x and y into z
# return (z, matching) if z != nonevalue; nonevalue otherwise.
unify(x,y) = (m = Matching(); z = unify(m, x,y); is(z, nonevalue) ? z : (z, m))


# Match if equal. This is the only unification that applies to atoms.
function unify(m::Matching, x::Pattern,y) 
    error("Unimplemented: unify(::Matching, ::$(typeof(x)), ::$(typeof(y)))")
end
function unify(m::Matching, x,y) 
    isa(y,Pattern) ? unify(m, y,x) : (isequal(x,y) ? x : nonevalue)
end

unify(m::Matching, X::PVar,     y)       = meet(m, X,y)
unify(m::Matching, X::Universal,y::TVar) = meet(m, y.X,y)
unify(m::Matching, X::Universal,y)       = y

# Note: calls unify(::Matching, ::Union(PVar,Universal),y::Typed)
unify{T}(m::Matching, X::Typed{T},y) = unify(m, get_p(X), restrict(T, y))


# -- Vector unification -------------------------------------------------------

function unify(m::Matching, xs::Vector, ys::Vector)
    nx, ny = map(length, (xs, ys))
    if nx != ny;  return  nonevalue;  end

    T = tintersect(eltype(xs),eltype(ys))
    if is(T,None);  return nonevalue;  end

    zs = Array(T,nx)
    for k=1:nx
        zs[k] = (@retnaught unify(m, xs[k],ys[k]))
    end
    zs
end

