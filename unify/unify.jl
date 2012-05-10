
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

typealias AnyVar PVar{Any}

pvar(name::Symbol) = PVar{Any}(VarId(name))
pvar(T, name::Symbol) = PVar{T}(VarId(name))
pvar{T}(::Domain{T}, id::VarId) = PVar{T}(id)
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


# -- restrict -----------------------------------------------------------------

restrict{T}(::Domain{T}, x) = restrict(T, x)
restrict{T}(R::Type, ::Domain{T}) = Domain(tintersect(R,T))
restrict(R::Type, X::PVar) = pvar(restrict(R,X.dom), X.id)
restrict(R::Type, x) = isa(x, R) ? x : nonematch  # for non-Patterns
