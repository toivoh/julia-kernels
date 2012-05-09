
load("utils/req.jl")
req("utils/utils.jl")


# -- PVar ---------------------------------------------------------------------

type PVar
    name::Symbol
end

# PVar:s compare by name --- or should it be by identity?
isequal(X::PVar, Y::PVar) = isequal(X.name, Y.name)
hash(X::PVar) = hash(X.name)

pvar(name::Symbol) = PVar(name)
pvar(args::(Symbol...)) = map(pvar, args)

macro pvar(args...)
    quoted_args = {quoted_expr(a) for a in args}
    quote
       ($quoted_tuple(args)) = pvar($quoted_tuple(quoted_args))
    end
end


typealias Match Dict
type Naught; end;
const naught = Naught() # the pattern that matches nothing
type Anything; end
const anything = Anything()   # the pattern that matches anything

unify(m::Match, x, y) = isequal(x, y) ? x : naught

unify(m::Match, ::Anything, ::Anything) = anything
unify(m::Match, x, ::Anything) = x
unify(m::Match, ::Anything, x) = x

unify(m::Match, ::Naught, ::Naught) = naught
unify(m::Match, ::Anything, ::Naught) = naught
unify(m::Match, ::Naught, ::Anything) = naught
unify(m::Match, x, ::Naught) = naught
unify(m::Match, ::Naught, x) = naught

function unify(m::Match, x::Tuple, y::Tuple)
    n = length(x)
    if length(y) != n; return naught; end
    zs = cell(n)
    for k=1:n
        z = unify(m, x, y)
        if is(z, naught); return naught; end
    end
    return tuple(z)
end

unify(m::Match, X::PVar, Y::PVar) = ubind(m, X, Y)
unify(m::Match, X::PVar, y) = ubind(m, X, y)
unify(m::Match, x, Y::PVar) = ubind(m, Y, x)

# bind X=y in m, and return the unification of X and y
function ubind(m, X::PVar, y)
    if has(m, X)
        x = unify(m, m[X], y)
        if is(x, naught); return naught; end
        m[X] = x
    else
        m[X] = y
        return y
    end
end


typealias Cattable Union(Tuple, PVar)
type TupleCat{T<:(Cattable...)}
    terms::T
end

~(x::Tuple, y::Tuple) = append(x, y)
~(X::TupleCat, Y::TupleCat) = TupleCat(X.terms~Y.terms)
~(x::Cattable, y::Cattable) = TupleCat((x,y))
~(X::TupleCat, y::Cattable) = TupleCat(X.terms~(y,))
~(x::Cattable, Y::TupleCat) = TupleCat((x,)~Y.terms)




# pmatch(m::Match, x, y) = isequal(x, y) # default matching: straight equality
# unify(m::Match, x, y) = isequal(x, y) ? x : nomatch

# function pmatch(m::Match, x::Tuple, y::Tuple) 
#     ((n=length(x))==length(y)) & allp(k->pmatch(m,x[k],y[k]), 1:n)
# end
# function unify(m::Match, x::Tuple, y::Tuple)
    
# end


# pmatch(m::Match, X::PVar, Y::PVar) = pbind(m, X, Y)
# pmatch(m::Match, X::PVar, y) = pbind(m, X, y)
# pmatch(m::Match, x, Y::PVar) = pbind(m, Y, x)

# function pbind(m, X::PVar, y)
#     if has(m, X)
# #        if !pmatch(m, m[X], y) # todo: should this recursive matching work?
#         if !isequal(m[X], y)
#             return false
#         end
#     else
#         m[X] = y
#     end
#     return true
# end











# # -- pattern types ------------------------------------------------------------

# type HXTPattern
#     head::Tuple
#     X::PVar
#     tail::Tuple
# end

# show(io::IO, P::HXTPattern) = (print(io, P.head, "~", P.X, "~", P.tail))


# # -- operations ---------------------------------------------------------------

# ~(x::Tuple, y::Tuple) = append(x, y)

# promote_tpat(t::Tuple) = t
# promote_tpat(X::PVar) = HXTPattern((),X,())
# promote_tpat(X::HXTPattern) = X

# typealias TuplePattern Union(Tuple, PVar, HXTPattern)
# ~(X::TuplePattern, Y::TuplePattern) = ~(promote_tpat(X), promote_tpat(Y))

# ~(X::HXTPattern, Y::HXTPattern) = error("unimplemented: "*
#                                         "concatenation of HXTPattern:s")
# ~(x::Tuple, Y::HXTPattern) = HXTPattern(x~Y.head, Y.X, Y.tail)
# ~(X::HXTPattern, y::Tuple) = HXTPattern(X.head, X.X, X.tail~y)

# # -- pmatch -------------------------------------------------------------------

# typealias Match Dict
# const nomatch = nothing

# pmatch(x, y) = (m = Match(); pmatch(m, x, y) ? m : nomatch)

# pmatch(m::Match, x, y) = isequal(x, y) # default matching: atoms
# function pmatch(m::Match, s::Tuple, t::Tuple)
#     n = length(s)
#     if n != length(t)
#         return false
#     end
#     return allp(pair->pmatch(m,pair[1],pair[2]), zip(s, t))
# end
# pmatch(m::Match, X::PVar, Y::PVar) = pmatch_bind(m, X, Y)
# pmatch(m::Match, X::PVar, y) = pmatch_bind(m, X, y)
# pmatch(m::Match, x, Y::PVar) = pmatch_bind(m, Y, x)

# function pmatch_bind(m, X::PVar, y)
#     if has(m, X)
# #        if !pmatch(m, m[X], y) # todo: should this recursive matching work?
#         if !isequal(m[X], y)
#             return false
#         end
#     else
#         m[X] = y
#     end
#     return true
# end

# pmatch(m::Match, P::HXTPattern, Q::HXTPattern) = error("unimplemented: "*
#                                                   "pmatch of two HXTPattern:s")
# function pmatch(m::Match, P::HXTPattern, t::Tuple)
#     nH, nT = length(P.head), length(P.tail)
#     if nH+nT > length(t)
#         return false
#     end
#     pmatch(m, (P.head,  P.X,                P.tail), 
#               (t[1:nH], t[(nH+1):(end-nT)], t[(end-nT+1):end]))
# end
# pmatch(m::Match, t::Tuple, P::HXTPattern) = pmatch(m, P, t)
