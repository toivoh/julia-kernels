
load("utils/req.jl")
req("utils/utils.jl")
#req("pdispatch/meta.jl")
req("pdispatch/patterns.jl")


function split_fdef(fdef::Expr)
    @expect (fdef.head == :function) || (fdef.head == :(=))
    @expect length(fdef.args) == 2
    signature, body = tuple(fdef.args...)
    @expect is_expr(signature, :call)
    @expect length(signature.args) >= 1
    (signature, body)
end
split_fdef(f::Any) = error("split_fdef: expected function definition, got\n$f")


# == code_pmatch ==============================================================

# -- PMContext ----------------------------------------------------------------

type PVarEntry
    name::Symbol  # name of the variable to hold the value bound to the pvar
    isassigned::Bool # has a value been bound to name yet?

    PVarEntry(name::Symbol) = new(name, false)
end
type PMContext
    vars::Dict{PVar, PVarEntry}  # pvars => match variables
    nomatch_ex    # expr to be returned if match fails
    code::Vector  # generated exprs

    PMContext(nomatch_ex) = new(Dict{PVar, PVarEntry}(), nomatch_ex, {})
    PMContext() = PMContext(:false)
end

emit(c::PMContext, ex) = (push(c.code,ex); nothing)

function get_entry(c::PMContext, p::PVar)
    if !has(c.vars, p)
#        c.vars[p] = PVarEntry(gensym(string(p.name)))
        c.vars[p] = PVarEntry(p.name)
#        error("code_pmatch: undefined PVar p = ", p)
    end
    entry = c.vars[p]
end


# -- code_pmatch --------------------------------------------------------------

function code_iffalse_ret(c::PMContext, pred)
    :(if !($pred)
        return ($c.nomatch_ex)
    end)
end

function code_pmatch(c::PMContext, ::NonePattern,::Symbol) 
    error("code_pmatch: pattern never matches")
end
function code_pmatch(c::PMContext, p::PVar,xname::Symbol)
    entry = get_entry(c, p)
    if entry.isassigned
        emit(c, code_iffalse_ret(c, :( isequal(($entry.name),($xname))) ))
    else
        if !isuniversal(p.dom)
            emit(c, code_iffalse_ret(c, code_contains(p.dom,xname)))
        end
        emit(c, :(
            ($entry.name) = ($xname)
        ))
        entry.isassigned = true
    end
end
function code_pmatch(c::PMContext, p::RuntimeValue,xname::Symbol)
    emit(c, code_iffalse_ret(c, :( isequal(($p.name),($xname)) )))
end
function code_pmatch(c::PMContext, p,xname::Symbol)
    @assert isatom(p)
    emit(c, code_iffalse_ret(c, :( isequal(($quoted_expr(p)),($xname)) )))
end
function code_pmatch_list(T, c::PMContext, ps,xname::Symbol)
    np = length(ps)
    emit(c, code_iffalse_ret(c,  :(
        (isa(($xname),($quoted_expr(T))) && length($xname) == ($np))
    )))
    for k=1:np
        xname_k = gensym()
        emit(c, :(($xname_k) = ($xname)[$k]))
        code_pmatch(c, ps[k], xname_k)
    end
end
function code_pmatch(c::PMContext, ps::Tuple,xname::Symbol)
    code_pmatch_list(Tuple, c, ps,xname)
end
function code_pmatch(c::PMContext, ps::Vector,xname::Symbol)
    code_pmatch_list(Vector, c, ps,xname)
end



# == unify ====================================================================

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


# -- Subs ---------------------------------------------------------------------

# A substitution from pattern variables to patterns/values
type Subs
    dict::Dict{PVar,Any}  # substitions p::PVar => dict[p]
    nPgeX::Bool           # true if unite(s, P,X) has disproved that P >= X
    overdet::Bool         # true if no feasible substitution exists

    Subs() = new(Dict{PVar,Any}(), false, false)
end
nge!(s::Subs) = (s.nPgeX = true; s)

function show(io::IO,s::Subs) 
    ge = s.nPgeX ? "  " : ">="
    print(io, s.overdet ? "Nosubs($ge)" : "Subs($ge, $(s.dict))")
end

type Unfinished; end             
# Value of an unfinished computation. Used to detect cyclic dependencies.
const unfinished = Unfinished()

# rewrite all substitutions in s to depend only on free PVar:s
function unwind!(s::Subs)
    keys = [entry[1] for entry in s.dict]
    foreach(key->(s[key]), keys)
end

# s[p]:  apply the substitution s to the pattern p
function ref(s::Subs, V::PVar)
    if s.overdet;  return nonematch;  end
    if has(s.dict, V)
        p = s.dict[V]
        if is(p, unfinished)
            # circular dependency ==> no finite pattern matches
            s.overdet = true
            return s.dict[V] = nonematch
        elseif isatom(p)
            return p  # atoms can't be further substituted
        else
            # apply any relevant substitutions in s to p
            s.dict[V] = unfinished  # mark unfinished to avoid infinite loops
            p = s[p]                # look up recursively
            return s.dict[V] = p    # store new value and return
        end
    else
        return V  # free PVar ==> return V itself
    end
end
# substitution on each item in a list
function ref_list{T}(::Type{T}, s::Subs, xs)
    n = length(xs)
    ys = Array(T, n)
    for k=1:n
        @retnone y = s[xs[k]]
        ys[k] = y
    end
    ys
end
ref{T}(s::Subs, xs::Vector{T}) = (isatomtype(T) ? xs : ref_list(T, s, xs))
function ref(s::Subs, xs::Tuple)
    @retnone ys=ref_list(Any, s, xs)
    tuple(ys...)
end
function ref(s::Subs, x)
    @assert isatom(x)
    x  # return atoms unchanged
end


# Y = unitesubs(s::Subs, V::PVar,X)
# ------------------------------------
# Add the constraint V == p to s, and return the new binding pnew for V

function unitesubs(s::Subs, V::PVar,p)
    if has(s.dict, V)
        p0 = s[V]  # look up the refined value of V
        # consider: any other cases when this is not a new constraint?
        # (especially when !s.nPgeX)
        if is(p,V) || isequal(p,p0);  return p0;  end
        # !s.nPgeX ==> this introduces constraints on rhs
        #          ==> s.nPgeX = true
        pnew = unite(nge!(s), p0,p)    # unite the new value with the old
        return s.dict[V] = pnew        # store the result and return
    else
        s.dict[V] = p  # no old binding: store and return the new one
    end
end


# -- unite --------------------------------------------------------------------

# unify x and y into z
# return (z, substitution)
function unify(x,y)
    s = Subs()
    z = unite(s, x,y)
    if is(z, nonematch)
        # todo: move this into Subs/unite/check if it's already there
        s.overdet = true
        s.nPgeX = !is(y,nonematch)
    else        
        # make sure all available substitutions have been applied
        unwind!(s)
        z = s[z]
    end
    (z, s)
end

pattern_le(x,y) = (s=unify(y,x)[2]; !s.nPgeX)
pattern_ge(x,y) = (s=unify(x,y)[2]; !s.nPgeX)
pattern_eq(x,y) = pattern_le(x,y) && pattern_ge(x,y)


# Y = unite(s::Subs, P,X):
# unite the patterns P and X into Y, and update s with the necessary
# substitutions such that 
# 
#   Z == s[P] == s[X]
#
# If P dominates X, then Y == X

# might show !(P >= X); unify will take care of it
unite(s::Subs, ::NonePattern,X) = nonematch  

function unite(s::Subs, P::PVar,X::PVar)
    if is(X,P); return X; end
    if P.dom >= X.dom; return unitesubs(s, P,X)
    elseif X.dom >= P.dom; return unitesubs(nge!(s), X,P)   # ==> !(P >= X)
    else
        I = PVar(gensym("pvar"), dintersect(P.dom, X.dom))  # ==> !(P >= X)
        return unite(s, P,unite(nge!(s), X,I))
    end
end
unite(s::Subs, P::PVar,X) = unitesubs(s, P,restr(P.dom, X))
function unite(s::Subs, P,X) 
    if isa(X, Pattern); unite(nge!(s), X, P)          # ==> !(P >= X)
    else;               isequal(P,X) ? X : nonematch  # for atoms
    end
end


# -- tuple unification --------------------------------------------------------

function unite_list{T}(::Type{T}, s::Subs, ps, xs)
    np, nx = length(ps), length(xs)
    if np!=nx; return nonematch; end
    ys = Array(T, np)
    for k=1:np
        @retnone y = unite(s, ps[k], xs[k])
        ys[k] = y
    end
    ys
end

unite{T}(s::Subs, ps::Vector,xs::Vector{T}) = unite_list(T, s, ps,xs)
function unite(s::Subs, ps::Tuple,xs::Tuple) 
    @retnone ys=unite_list(Any, s, ps,xs)
    tuple(ys...)
end
