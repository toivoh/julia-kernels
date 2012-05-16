
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

pattype{T}(::Pattern{T}) = T

show(io::IO, ::NonePattern) = print(io, "nonematch")


isatomtype(::Tuple) = false
isatomtype{T,N}(::Type{Array{T,N}}) = isatomtype(T)
isatomtype(T) = !(T <: Array || Pattern <: T || T <: Pattern)

isatom(x::Tuple) = false
isatom(x) = isatomtype(typeof(x))


## restr: domain restriction for non-PVar:s ##
restr( ::Domain{Any}, ::NonePattern) = nonematch
restr( ::Domain,      ::NonePattern) = nonematch
restr( ::Domain{Any}, x) = x

#restr{T}(::Domain{T}, x) = isa(x, T) ? x : nonematch
restr{T}(::Domain{T}, x::T) = x
function restr{T}(::Domain{T}, x)
    try
        y = convert(T, x)
        isequal(x,y) ? y : nonematch
    catch err
        nonematch
    end
end

restr{T}(::Type{T}, x) = restr(domain(T), x)


# -- RuntimeValue -------------------------------------------------------------

type RuntimeValue <: Pattern{Any} # todo: parametrize by value type and domain
    name::Symbol
end


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
show{T}(io::IO, V::PVar{T}) = print(io, "pvar(:$(V.name),$T)")

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


promote_rule{S,T}(::Type{PVar{S}}, ::Type{PVar{T}}) = PVar
promote_rule{S<:Pattern,T<:Pattern}(::Type{S}, ::Type{T}) = Pattern
# consider: A these two rules too strong?
promote_rule{T<:Pattern}(::Type{T}, ::Any) = Any
promote_rule(::Type{Any}, ::Any) = Any

