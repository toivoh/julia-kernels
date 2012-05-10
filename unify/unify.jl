
load("utils/req.jl")
req("utils/utils.jl")

# Patterns that can match a different type than their own
abstract Pattern
# Patterns without a specified value type
abstract Untyped <: Pattern

# A pattern that only matches objects of type <: T
type Typed{T} <: Pattern
    p::Untyped
end

type Universal <: Untyped; end
const anyvalue  = Universal()            # The pattern that matches anything
const nonevalue = Typed{None}(anyvalue)  # The pattern that matches nothing

# todo: Can I make the inner constructor always return nonevalue
# when T = None too?
# consider: should Typed have subtypes for Universal vs PVar content?
Typed{T}(::Type{T}, p::Untyped) = is(T,None) ? nonevalue : Typed{T}(p)

valtype{T}(::Typed{T}) = T


show(io::IO, ::Universal) = print(io, "anyvalue")
show(io::IO, p::Typed{None}) = print(io, "nonevalue")
show{T}(io::IO, p::Typed{T}) = print(io, "Typed($T, $(p.p))")

# pattern variable, compares by identity
type PVar <: Untyped
    name::Symbol
end

pvar(name::Symbol) = PVar(name)
pvar(names::(Symbol...)) = map(pvar, names)

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    # todo: allow syntax @pvar X::Int ?
    quoted_args = {quoted_expr(a) for a in args}
    quote
       ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
    end
end


# Return a pattern that matches any value of type T
match(T) = Typed(T, anyvalue)

# restrict(T, x): 
# Return the restriction of the pattern x to value type T
restrict(::Type{Any}, x) = x
restrict(::Type{Any}, x::Typed) = x
restrict(::Type{Any}, x::Untyped) = x

restrict{T}(R, t::Typed{T}) = restrict(tintersect(R,T), t.p)
restrict(T, p::Untyped) = Typed(T, p)
restrict(T, x) = isa(x, T) ? x : nonevalue  # for non-Pattern:s




# -- unify --------------------------------------------------------------------

# Matching of pattern variables to values
typealias Matching Dict{PVar, Any}

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

unify(m::Matching, ::Universal,y) = y
unify(m::Matching, X::PVar,y)  = ubind(m, X,y)

# Note: calls unify(::Matching, X::Untyped,y::Typed);
# unify(::Matching, X::Untyped,y) is defined for all X!
unify{T}(m::Matching, X::Typed{T},y) = unify(m, X.p, restrict(T, y))

# bind X => y in b, and return the unification of X and y given b
function ubind(m::Matching, X::PVar,y)
    if has(m, X) 
        # unify the present binding of X with the new one
        x = m[X]
        z = unify(m, x,y)
        if is(z,X); return X; end
        return m[X] = z
    else
        if is(y,anyvalue); return X; end
        if isa(y,Typed) && is(y.p, anyvalue)
            return m[X] = restrict(valtype(y), X)
        end
        return m[X] = y
    end
end






