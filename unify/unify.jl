
load("utils/req.jl")
req("utils/utils.jl")

# Patterns that can match a different type than their own
abstract Pattern

# A pattern that only matches objects of type <: T
type Restrict{T} <: Pattern
    x
end

type Anything <: Pattern; end
const anything = Anything()             # The pattern that matches anything
const naught = Restrict{None}(anything) # The pattern that matches nothing

type PVar <: Pattern  # pattern variable, compares by identity
    name::Symbol
end

pvar(name::Symbol) = PVar(name)
pvar(names::(Symbol...)) = map(pvar, names)


#pattype{T}(::Pattern{T}) = T
pattype{T}(::Restrict{T}) = T
pattype(::Pattern) = Any
pattype{T}(::T) = T

isnaught(x) = is(pattype(x), None)

# restrict(T, x): The restriction of the pattern x to type T
restrict{T}(::Type{None}, ::T)           = naught  
restrict{T}(::Type{None}, ::Restrict{T}) = naught  # todo: do I really
restrict{T<:Pattern}(::Type{None}, ::T)  = naught  # need these two?

restrict{T}(S, R::Restrict{T}) = restrict(tintersect(S,T), R.x)
restrict(T, X::Pattern) = Restrict{T}(X)
restrict(T, x) = isa(x, T) ? x : naught

show(io::IO, R::Restrict{None}) = print(io, "naught")
show{T}(io::IO, R::Restrict{T}) = print(io, "restrict($T, $(R.x))")


# -- unify --------------------------------------------------------------------

# Binding of pattern variables to values
typealias Binding Dict{PVar, Any}

# (@retnaught x) returns naught from the function if x is naught;
# evaluates to x otherwise.
macro retnaught(ex)
    @gensym p
    quote
        ($p) = ($ex)
        if is(($p), naught);  return naught;  end
        ($p)
    end
end

# unify(b::Binding, x, y)
# -----------------------
# Find the bindings needed to make the patterns x==y,
# (along with the ones already present in b), 
# and store them in b.
# Return the unification z = (x given b) = (y given b),
# or naught if the match is not possible.

# unify x and y into z, return (z, binding) if it's possible; naught otherwise.
unify(x,y) = (b = Binding(); z = unify(b, x,y); is(z, naught) ? z : (z, b))


# Match if equal. This is the only unification that applies to atoms.
unify(b::Binding, x,y) = isequal(x,y) ? x : naught

unify(b::Binding, X::PVar,Y::PVar)  = ubind(b, X,Y)
unify(b::Binding, X::PVar,y) = ubind(b, X,y)
unify(b::Binding, x,Y::PVar) = ubind(b, Y,x)
unify(b::Binding, R::Restrict,X::PVar) = ubind(b, X,R)
unify(b::Binding, X::PVar,R::Restrict) = ubind(b, X,R)

# bind X => y in b, and return the unification of X and y given b
#ubind(b::Binding, X::PVar,::Anything) = get(b,X,anything)
function ubind(b::Binding, X::PVar,y)
#    if (is(y,X)) || is(y,anything); return get(b,X,y); end
    if has(b, X) 
        # unify the present binding of X with the new one
        x = b[X]
        z = unify(b, x,y)
        if is(z,x) || is(z,anything); return z; end
        return b[X] = z
    else
        if is(y,anything); return anything; end
        return b[X] = y
    end
end

function unify{T}(b::Binding, P::Restrict,R::Restrict{T})
    unify(b, restrict(T, P), R.x)
end
unify{T}(b::Binding, x,R::Restrict{T}) = unify(b, restrict(T,x),R.x)
unify{T}(b::Binding, R::Restrict{T},x) = unify(b, restrict(T,x),R.x)




