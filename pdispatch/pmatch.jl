
load("utils/req.jl")
req("utils/utils.jl")
req("pdispatch/meta.jl")


# == code_pmatch ==============================================================

# -- PMContext ----------------------------------------------------------------

type PVarEntry
    name::Symbol
    isassigned::Bool
    PVarEntry(name::Symbol) = new(name, false)
end
type PMContext
    vars::Dict{PVar, PVarEntry}
    ret_nomatch
    code::Vector

    PMContext(ret_nomatch) = new(Dict{PVar, PVarEntry}(), ret_nomatch, {})
    PMContext() = PMContext(:false)
end

PMContext(rpc::RPContext, args...) = PMContext(rpc.vars, args...)
function PMContext(vars::Dict, args...)
    c = PMContext(args...)
    for (name::Symbol, p::PVar) in vars
        c.vars[p] = PVarEntry(name)
    end
    c
end

emit(c::PMContext, ex) = (push(c.code,ex); nothing)

function get_entry(c::PMContext, p::PVar)
    if !has(c.vars, p)
#        c.vars[p] = PVarEntry(gensym(string(p.name)))
#        c.vars[p] = PVarEntry(p.name)
        error("code_pmatch: undefined PVar p = ", p)
    end
    entry = c.vars[p]
end


# -- code_pmatch --------------------------------------------------------------

function code_iffalse_ret(c::PMContext, pred)
    :(if !($pred)
        return ($c.ret_nomatch)
    end)
end

code_pmatch(c::PMContext, ::NonePattern,::Symbol) = error("code_pmatch: "*
                                                  "pattern never matches")
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
    dict::Dict{PVar,Any}
    overdet::Bool

    Subs() = new(Dict{PVar,Any}(), false)
end

function show(io::IO,s::Subs) 
    print(io, s.overdet ? "Nosubs()" : "Subs($(s.dict))")
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
