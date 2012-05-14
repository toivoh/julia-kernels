
load("utils/req.jl")
req("utils/utils.jl")


# -- Domain -------------------------------------------------------------------

# The domain of values of type T
type Domain{T}; end
domain{T}(::Type{T}) = Domain{T}()

const nonedomain = domain(None)

domtype{T}(::Domain{T}) = T

<={S,T}(D::Domain{S}, E::Domain{T}) = (S<:T)
>={S,T}(D::Domain{S}, E::Domain{T}) = (T<:S)


dintersect(::Domain{Any}, ::Domain{Any}) = domain(Any)
dintersect(::Domain{Any}, D::Domain) = D
dintersect(D::Domain, ::Domain{Any}) = D
dintersect{S,T}(D::Domain{S}, E::Domain{T}) = domain(tintersect(S,T))

isuniversal(::Domain{Any}) = true
isuniversal(::Domain)      = false
code_contains{T}(D::Domain{T}, ex) = :(isa(($ex),($quoted_expr(T))))


# -- Pattern ------------------------------------------------------------------

# Patterns that can match a value type different from their own type;
# only value types <: T
abstract Pattern{T}

type NonePattern <: Pattern{None}; end
const nonematch = NonePattern()

patype{T}(::Pattern{T}) = T

show(io::IO, ::NonePattern) = print(io, "nonematch")


isatom(::Pattern) = false
isatom(::Any)     = true

## restr: domain restriction for non-PVar:s ##
restr( ::Domain{Any}, ::NonePattern) = nonematch
restr( ::Domain,      ::NonePattern) = nonematch
restr( ::Domain{Any}, x) = x

restr{T}(::Domain{T}, x) = isa(x, T) ? x : nonematch

restr{T}(::Type{T}, x) = restr(domain(T), x)


# -- PVar ---------------------------------------------------------------------

# Pattern variable that only matches values of type <: T
type PVar{T} <: Pattern{T}
    name::Symbol
    dom::Domain{T}

    PVar(name::Symbol) = is(T,None) ? nonematch : new(name, domain(T))
end
typealias AnyVar PVar{Any}

PVar(   name::Symbol, ::Domain{None}) = nonematch
PVar{T}(name::Symbol, ::Domain{T})    = PVar{T}(name)
PVar{T}(name::Symbol, ::Type{T})      = PVar{T}(name)


pvar(name::Symbol, T) = PVar(name, T)
pvar(name) = pvar(name, Any)

#match(T) = PVar(T, gensym("match_$T"))
match(T) = PVar(gensym(), T)

show(io::IO, V::AnyVar) = print(io, "pvar(:$(V.name))")
show{T}(io::IO, V::PVar{T}) = print(io, "pvar($T,:$(V.name))")

# usage: @pvar X Y   ==> X, Y = pvar((:X, :Y))
macro pvar(args...)
    code_pvar(args...)
end
function code_pvar(args...)
    if (length(args)==1) && (is_expr(args[1], :tuple))
        return code_pvar(args[1].args...)
    end

    pvarcalls = {}
    argnames = {}
    for arg in args
        argname = arg
        if is_expr(arg, doublecolon)
            @expect length(arg.args) == 2
            argname, argtype = arg.args[1], arg.args[2]
            push(pvarcalls, :( pvar($quoted_expr(argname),($argtype)) ))
        else
            push(pvarcalls, :( pvar($quoted_expr(arg)) ))
        end 
        push(argnames, argname::Symbol)
    end
    quote
        ($quoted_tuple(argnames)) = ($quoted_tuple(pvarcalls))
        nothing
    end
end



# (@retnone x) returns nonematch from the function if x is nonematch;
# evaluates to x otherwise.
macro retnone(ex)
    @gensym p
    quote
        ($p) = ($ex)
        if is(($p), nonematch);  return nonematch;  end
        ($p)
    end
end

promote_rule{S,T}(::Type{PVar{S}}, ::Type{PVar{T}}) = PVar
promote_rule{S<:Pattern,T<:Pattern}(::Type{S}, ::Type{T}) = Pattern
# consider: A these two rules too strong?
promote_rule{T<:Pattern}(::Type{T}, ::Any) = Any
promote_rule(::Type{Any}, ::Any) = Any


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

function unwind!(s::Subs)
    keys = [entry[1] for entry in s.dict]
    foreach(key->(s[key]), keys)
end


function ref(s::Subs, V::PVar)
    if s.overdet;  return nonematch;  end
    if has(s.dict, V)
        v = s.dict[V]
        if is(v, unfinished)
            # circular dependency ==> no finite pattern matches
            s.overdet = true
            return s.dict[V] = nonematch
        elseif isatom(v)
            return v
        else
            s.dict[V] = unfinished  # mark unfinished to avoid infinite loops
            v = s[v]                # look up recursively
            return s.dict[V] = v    # store new value
        end
    else
        return V  # no value stored ==> return V itself
    end
end
function ref_list{T}(::Type{T}, s::Subs, xs)
    n = length(xs)
    ys = Array(T, n)
    for k=1:n
        @retnone y = s[xs[k]]
        ys[k] = y
    end
    ys
end
ref{T}(s::Subs, xs::Vector{T}) = ref_list(T, s, xs)
#ref(s::Subs, xs::Tuple) = ((@retnone ys=ref_list(T, s, xs)); tuple(ys))
function ref(s::Subs, xs::Tuple)
    @retnone ys=ref_list(Any, s, xs)
    tuple(ys)
end
ref(s::Subs, x) = x  # return atoms unchanged


# Y = unitesubs(s::Subs, V::PVar,X)
# ------------------------------------
# Add the constraint V == X to s, and return the new binding Y for V

function unitesubs(s::Subs, V::PVar,X)
    if is(X,V);  return X;  end
    if has(s.dict, V)
        v = s[V]
        Y = unite(s, v,X)     # unite the new value with the old
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
    if is(z, nonematch)
        s.overdet = true
    else        
        unwind!(s)
        z = s[z]
    end
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
    if is(X,P); return X; end
    if P.dom >= X.dom; return unitesubs(s, P,X)
    elseif X.dom >= P.dom; return unitesubs(s, X,P)
    else
        I = PVar(gensym("pvar"), dintersect(P.dom, X.dom))
        return unite(s, P,unite(s, X,I))
    end
end
unite(s::Subs, P::PVar,X) = unitesubs(s, P,restr(P.dom, X))
function unite(s::Subs, P,X) 
    if isa(X, Pattern); unite(s, X,P)                 # disproves that X <= P
    else;               isequal(P,X) ? X : nonematch  # for atoms
    end
end


# -- tuple unification --------------------------------------------------------

isatom(::Tuple) = false
isatom(::Vector) = false

function unite_list{T}(::Type{T}, s::Subs, ps, xs)
    np, nx = length(ps), length(xs)
    if np!=nx; return nonematch; end
    ys = Array(T, np)
    for k=1:np
        @retnone y = unite(s, ps[k], xs[k])
#         println()
#         @show y = unite(s, ps[k], xs[k])
#         @show s
#         @retnone y 
        ys[k] = y
    end
    ys
end

unite{T}(s::Subs, ps::Vector,xs::Vector{T}) = unite_list(T, s, ps,xs)
function unite(s::Subs, ps::Tuple,xs::Tuple) 
    @retnone ys=unite_list(Any, s, ps,xs)
    tuple(ys)
end


