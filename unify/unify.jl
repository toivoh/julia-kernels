
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


# == Subs =====================================================================

type Subs
    d::Dict{PVar,Any}
    overdet::Bool
    Subs() = new(Dict{PVar,Any}())
end

type Unfinished; end
const unfinished = Unfinished()  # used to detect cyclic dependencies

# circular dependency ==> no finite pattern matches
expand(s::Subs, X::PVar,::Unfinished) = (s.overdet = true; s.d[X] = nonevalue)
expand(s::Subs,  ::PVar,::TypePattern) = error("TypePattern:s should "*
                                                   "never be stored in s.d")

function expand(s::Subs, x)
    @assert !is(x,X)    # should never store X=X
    if isa(x, TVar) && (is(x.X,X)); return x; end

    s.d[X] = unfinished
    x = s[x]             # look up x
    return s.d[X] = x    # store and return
end

function ref(s::Subs, X::PVar)
    if has(s.d, X)
        x = s.d[X]
        return expand(m, X,x)
    else
        return X
    end
end

# Add the constraint X==y in s, 
# and return the unification of X and y given s
function meet(s::Subs, X::PVar,y)
    todo: rewrite

    x = s.d[X]
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
    return s.d[X] = z           # return new binding
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

# unify(s::Subs, x, y)
# -----------------------
# Find the bindings needed to make the patterns x==y,
# (along with the ones already present in b), 
# and store them in b.
# Return the unification z = (x given b) = (y given b),
# or nonevalue if the match is not possible.

# unify x and y into z
# return (z, matching) if z != nonevalue; nonevalue otherwise.
unify(x,y) = (s = Subs(); z = unify(s, x,y); is(z, nonevalue) ? z : (z, s))


# Match if equal. This is the only unification that applies to atoms.
function unify(s::Subs, x::Pattern,y) 
    error("Unimplemented: unify(::Subs, ::$(typeof(x)), ::$(typeof(y)))")
end
function unify(s::Subs, x,y) 
    isa(y,Pattern) ? unify(m, y,x) : (isequal(x,y) ? x : nonevalue)
end

unify(s::Subs, X::PVar,     y)       = meet(s, X,y)
unify(s::Subs, X::Universal,y::TVar) = meet(s, y.X,y)
unify(s::Subs, X::Universal,y)       = y

# Note: calls unify(::Subs, ::Union(PVar,Universal),y::Typed)
unify{T}(s::Subs, X::Typed{T},y) = unify(s, get_p(X), restrict(T, y))


# -- Vector unification -------------------------------------------------------

function unify(s::Subs, xs::Vector, ys::Vector)
    nx, ny = map(length, (xs, ys))
    if nx != ny;  return  nonevalue;  end

    T = tintersect(eltype(xs),eltype(ys))
    if is(T,None);  return nonevalue;  end

    zs = Array(T,nx)
    for k=1:nx
        zs[k] = (@retnaught unify(s, xs[k],ys[k]))
    end
    zs
end

