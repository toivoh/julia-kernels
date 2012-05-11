
# Pattern variable id. Compares buy type.
type VarId
    name::Symbol
end

# Patterns that can match a value type different from their own type;
# only value types <: T
abstract Pattern{T}


# -- Domain -------------------------------------------------------------------

# Pattern that matches all values of type T
type Domain{T} <: Pattern{T}; end
Domain{T}(::Type{T}) = Domain{T}()

typealias Universal Domain{Any}
typealias Unpattern Domain{None}

# Return a pattern that matches any value of type T
match(T) = Domain(T)

const anyvalue  = match(Any)   # The pattern that matches anything
const nonematch = match(None)  # The pattern that matches nothing

show(io::IO, ::Universal) = print(io, "anyvalue")
show(io::IO, ::Unpattern) = print(io, "nonematch")
show{T}(io::IO, p::Domain{T}) = print(io, "match($T)")


# -- PVar ---------------------------------------------------------------------

# Pattern variable that only matches values of type <: T
type PVar{T} <: Pattern{T}
    dom::Domain{T}
    id::VarId

#    PVar(id::VarId) = new(match(T), id)
    PVar(id::VarId) = is(T,None) ? nonematch : new(match(T), id)
end

PVar{T}(::Domain{T}, id::VarId) = PVar{T}(id)

typealias AnyVar PVar{Any}

pvar(name::Symbol) = PVar{Any}(VarId(name))
pvar(T, name::Symbol) = PVar{T}(VarId(name))
pvar(D::Domain, id::VarId) = PVar(T,id)
pvar(T, id::VarId) = PVar{T}(id)
pvar(::Type{None}, ::VarId) = nonematch
pvar(names::(Symbol...)) = map(pvar, names)

show(io::IO, p::AnyVar) = print(io, "pvar(:$(p.id.name))")
show{T}(io::IO, p::PVar{T}) = print(io, "pvar($T,:$(p.id.name))")

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    # todo: allow syntax @pvar X::Int ?
    quoted_args = {quoted_expr(a) for a in args}
    quote
       ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
    end
end


# -- dintersect --------------------------------------------------------------

# intersect a domain with a pattern
dintersect{R,T}(::Domain{R}, ::Domain{T}) = Domain(tintersect(R,T))
dintersect(D::Domain, X::PVar) = PVar(dintersect(D, X.dom), X.id)
dintersect{T}(::Domain{T}, x) = isa(x, T) ? x : nonematch  # for non-Patterns

restrict{T}(::Type{T}, x) = dintersect(Domain(T), x)

