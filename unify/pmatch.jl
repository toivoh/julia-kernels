
load("utils/req.jl")
req("utils/utils.jl")

# -- pattern types ------------------------------------------------------------

# Patterns that are restricted to match values of type T
# (and are not of the actual type T)
abstract Pattern{T}

# The pattern that matches all values of type T
type Match{T} <: Pattern{T}; end
match{T}(::Type{T}) = Match{T}()

typealias Anything Match{Any} # The pattern that matches anything
typealias Naught Match{None}  # The pattern that matches nothing
const anything = Anything()
const naught = Naught()

show(   io::IO,  ::Anything) = print(io, "anything")
show(   io::IO,  ::Naught)   = print(io, "naught")
show{T}(io::IO, m::Match{T}) = print(io, "match($T)")


# pattern variable that is restricted to match values of type T
type PVar{T} <: Pattern{T}
    name::Symbol
end

pvar(T, name::Symbol) = PVar{T}(name)
pvar(name::Symbol) = pvar(Any, name)


pattype{T}(::Pattern{T}) = T
pattype{T}(::T) = T

# -- unify --------------------------------------------------------------------

# Binding of pattern variables to values
typealias Binding Dict{PVar, Any}

# (@retnaught x) returns naught from the function if x is naught,
# and evaluates to x otherwise.
macro retnaught(ex)
    @gensym p
    quote
        ($p) = ($ex)
#        is(($p), naught) ? (return ($p)) : ($p)
        if is(($p), naught)
            return naught
        end
        ($p)
    end
end

unify(x, y) = (b = Binding(); z = unify(b, x, y); is(z, naught) ? z : (z, b))

# unify(b::Binding, x, y)
# -----------------------
# Find the bindings needed to make the patterns x==y,
# (along with the ones already present in b), 
# and store them in b.
# Return the unification z = (x given b) = (y given b),
# or naught if the match is not possible.

# Match if equal. This is the only unification that applies to atoms.
unify(b::Binding, x, y) = isequal(x,y) ? x : naught

unify{S,T}(b::Binding, ::Match{S}, ::Match{T}) = Match{tintersect(S,T)}()
# if x is of concrete type T, it unifies with Match{M} only if T <: M
unify{M,T}(b::Binding, ::Match{M}, x::T) = T<:M ? x : naught
unify{M,T}(b::Binding, x::T, ::Match{M}) = T<:M ? x : naught

unify(b::Binding, X::PVar,  Y::PVar)  = ubind(b, X, Y)
unify(b::Binding, X::PVar,  Y::Match) = ubind(b, X, Y)
unify(b::Binding, Y::Match, X::PVar)  = ubind(b, X, Y)
unify(b::Binding, X::PVar, y) = ubind(b, X, y)
unify(b::Binding, x, Y::PVar) = ubind(b, Y, x)

# bind X => y in b, and return the unification of X and y given b

function ubind{T}(b::Binding, X::PVar{T}, y)
    if pattype(y) <: T # y already fits within X
        if has(b, X)
            z = unify(b, b[X], y)
            return b[X] = z # (@retnaught z)
        else
            return b[X] = y
        end
    else  # narrow y down first
        z = unify(b, match(T), y)
        if !(pattype(z) <: T)
            @show z
            @show typeof(z)
            @show TX
            @assert false
        end
        return ubind(b, X, z)
    end
end



# -- Tuple matching -----------------------------------------------------------

# element d that corresponds to d... in a tuple
type Dots{T} # <: Pattern{T}
    X::Pattern{T}
end

dots{T<:Tuple}(t::Pattern{T}) = Dots{T}(t)


function unify(b::Binding, tx::Tuple, ty::Tuple)
    zs = {}
    ix = iy = 1
    nx, ny = length(tx), length(ty)
    while (ix <= nx) && (iy <= ny)
        x, y = tx[ix], ty[iy]
        if !(isa(x, Dots) || isa(y, Dots))
            z = unify(b, x, y)
            #if is(z, naught); return naught; end
            push(zs, (@retnaught z))
            ix += 1
            iy += 1
        else
            error("unimplemented: matching of Dots")
        end
    end
    tuple(zs...)
end
