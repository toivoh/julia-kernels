
load("utils/req.jl")
req("utils/utils.jl")


# Pattern variable id. Compares buy type.
type VarId
    name::Symbol
end

# The domain of values of type T
type Domain{T}; end
domain{T}(::Type{T}) = Domain{T}()

const nonedomain = domain(None)


dintersect(::Domain{Any}, ::Domain{Any}) = domain(Any)
dintersect(::Domain{Any}, D::Domain) = D
dintersect(D::Domain, ::Domain{Any}) = D
dintersect{S,T}(D::Domain{S}, E::Domain{T}) = domain(tintersect(S,T))


# -- Pattern ------------------------------------------------------------------

# Patterns that can match a value type different from their own type;
# only value types <: T
abstract Pattern{T}

type NonePattern <: Pattern{None}; end

const nonematch = NonePattern()


# -- PVar ---------------------------------------------------------------------

# Pattern variable that only matches values of type <: T
type PVar{T} <: Pattern{T}
    dom::Domain{T}
    id::VarId

    PVar(id::VarId) = is(T,None) ? nonematch : new(domain(T), id)
end
typealias AnyVar PVar{Any}

PVar(::Domain{None}, id::VarId) = nonematch
PVar{T}(::Domain{T}, id::VarId) = PVar{T}(id)
PVar{T}(::Type{T},   id::VarId) = PVar{T}(id)


pvar(T, id::VarId) = PVar(T, id)
pvar(T, name::Symbol) = pvar(T, VarId(name))
pvar(id) = pvar(Any, id)
pvar(names::(Symbol...)) = map(pvar, names)

show(io::IO, p::AnyVar) = print(io, "pvar(:$(p.id.name))")
show{T}(io::IO, p::PVar{T}) = print(io, "pvar($T,:$(p.id.name))")

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    # todo: allow syntax @pvar X::Int ?
    quoted_args = {quoted_expr(a) for a in args}
    quote
        ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
        nothing
    end
end


# -- restrict -----------------------------------------------------------------

restrict(D::Domain, ::NonePattern) = nonematch
restrict(D::Domain, P::PVar) = PVar(dintersect(D, P.dom), P.id)
restrict{T}(::Domain{T}, x) = isa(x, T) ? x : nonematch


# -- Subs ---------------------------------------------------------------------

# A substitution from pattern variables to patterns/values
type Subs
    d::Dict{PVar,Any}
    overdet::Bool

    Subs() = new(Dict{PVar,Any}(), false)
end

type Unfinished; end             
# Value of an unfinished computation. Used to detect cyclic dependencies.
const unfinished = Unfinished()


# Y = unitevalue(s::Subs, id::VarId,X)
# ------------------------------------
# Add the constraint PVar(id) == X to s
# and return the new binding for PVar(id)

function unitevalue(s::Subs, id::VarId,X)
    if has(s.d, Id)
        
    else
        s.d[id] = X
    end
end


# -- unite --------------------------------------------------------------------

# unify x and y into z
# return (z, substitution)
unify(x,y) = (s = Subs(); z = unite(s, x,y); (z, s))

# Y = unite(s::Subs, P,X):
# unite the patterns P and X into Y, and update s with the necessary
# substitutions such that 
# 
#   Z == s[P] == s[X]
#
# If P dominates X, then Y == X

unite(s::Subs, ::NonePattern,X) = nonematch
unite(s::Subs, P::AnyVar,X) = unitevalue(s, P.id,X)
unite(s::Subs, P::PVar,X) = unite(s, AnyVar(P.id), restrict(P.dom, X))
function unite(s::Subs, P,X) 
    if isa(X, Pattern); unite(s, X,P)  # disproved X <= P
    else isequal(P,X) ? X : nonematch  # for atoms
end
