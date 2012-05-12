
load("utils/req.jl")
req("utils/utils.jl")


# The domain of values of type T
type Domain{T}; end
domain{T}(::Type{T}) = Domain{T}()

const nonedomain = domain(None)

<={S,T}(D::Domain{S}, E::Domain{T}) = (S<:T)
>={S,T}(D::Domain{S}, E::Domain{T}) = (T<:S)


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


show(io::IO, ::NonePattern) = print(io, "nonematch")


# -- PVar ---------------------------------------------------------------------

# Pattern variable that only matches values of type <: T
type PVar{T} <: Pattern{T}
    dom::Domain{T}
    name::Symbol

    PVar(name::Symbol) = is(T,None) ? nonematch : new(domain(T), name)
end
typealias AnyVar PVar{Any}

PVar(::Domain{None}, name::Symbol) = nonematch
PVar{T}(::Domain{T}, name::Symbol) = PVar{T}(name)
PVar{T}(::Type{T},   name::Symbol) = PVar{T}(name)


pvar(T, name::Symbol) = PVar(T, name)
pvar(name) = pvar(Any, name)
pvar(defs::Tuple) = map(pvar, defs)

#match(T) = PVar(T, gensym("match_$T"))
match(T) = PVar(T, gensym())

show(io::IO, V::AnyVar) = print(io, "pvar(:$(V.name))")
show{T}(io::IO, V::PVar{T}) = print(io, "pvar($T,:$(V.name))")

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    # todo: allow syntax @pvar X::Int ?
    quoted_args = {quoted_expr(a) for a in args}
    quote
        ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
        nothing
    end
end


# -- restr --------------------------------------------------------------------

restr( ::Domain{Any}, ::NonePattern) = nonematch
restr( ::Domain,      ::NonePattern) = nonematch
restr( ::Domain{Any}, x) = x

restr{T}(::Domain{T}, x) = isa(x, T) ? x : nonematch

restr{T}(::Type{T}, x) = restr(domain(T), x)


# -- Subs ---------------------------------------------------------------------

# A substitution from pattern variables to patterns/values
type Subs
    dict::Dict{PVar,Any}
    overdet::Bool

    Subs() = new(Dict{PVar,Any}(), false)
end

function show(io::IO,s::Subs) 
    print(io, s.overdet ? "Unsubs()" : "Subs($(s.dict))")
end

type Unfinished; end             
# Value of an unfinished computation. Used to detect cyclic dependencies.
const unfinished = Unfinished()


function ref(s::Subs, V::PVar)
    if s.overdet;  return nonematch;  end
    if has(s.dict, V)
        v = s.dict[V]
        if is(v, unfinished)
            # circular dependency ==> no finite pattern matches
            s.overdet = true
            return s.dict[V] = nonematch
        elseif isa(v, Pattern)
            s.dict[V] = unfinished  # mark unfinished to avoid infinite loops
            v = s[v]                # look up recursively
            return s.dict[V] = v    # store new value
        else
            return v  # atom
        end
    else
        return V  # no value stored ==> return V itself
    end
end

# Y = unitesubs(s::Subs, V::PVar,X)
# ------------------------------------
# Add the constraint V == X to s, and return the new binding Y for V

function unitesubs(s::Subs, V::PVar,X)
    if has(s.dict, V)
        v = s[V]
        y = unite(s, v,X)     # unite the new value with the old
        return s.dict[V] = Y  # store the result and return
    else
        s.dict[V] = X
    end
end


# -- unite --------------------------------------------------------------------

# unify x and y into z
# return (z, substitution)
function unify(x,y)
    s = Subs()
    z = unite(s, x,y)
    if is(z, nonematch);  s.overdet = true; end
    (z, s)
end

# Y = unite(s::Subs, P,X):
# unite the patterns P and X into Y, and update s with the necessary
# substitutions such that 
# 
#   Z == s[P] == s[X]
#
# If P dominates X, then Y == X

unite(s::Subs, ::NonePattern,X) = nonematch
function unite(s::Subs, P::PVar,X::PVar)
    if P.dom >= X.dom; return unitesubs(s, P,X)
    elseif X.dom >= P.dom; return unitesubs(s, X,P)
    else
        I = PVar(dintersect(P.dom, X.dom), gensym("pvar"))
        return unite(s, P,unite(s, X,I))
    end
end
unite(s::Subs, P::PVar,X) = unitesubs(s, P,restr(P.dom, X))
function unite(s::Subs, P,X) 
    if isa(X, Pattern); unite(s, X,P)  # disproved X <= P
    else;               isequal(P,X) ? X : nonematch  # for atoms
    end
end
