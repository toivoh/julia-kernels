
load("unify/unify.jl")
load("utils/req.jl")
req("unify/test/symshow.jl")

@show @pvar X Y

@show X
@show pvar(Int, :Z)
@show pvar(Any, :Z)
@show pvar(None, :Z)

println()
@show restr(Int, 1)
@show restr(Float, 1)

println()
@symshow   unify(X, 3)
@symshowln unify(X, (4, "hej"))

println()
@showln    unify(match(Any), match(Any))
@symshowln unify(match(Any),     1)
@symshowln unify(match(Real),  1)
@symshowln unify(match(Int),   1)
@symshowln unify(match(Float), 1)
@symshowln unify(nonematch,    1)

println()
@show      unify(match(Real),  match(Real))
@symshowln unify(match(Real),  match(Int))
@symshowln unify(match(Float), match(Int))

Xr = pvar(Real,  :Xr)
Xi = pvar(Int,   :Xi)
Xf = pvar(Float, :Xf)

println()
@symshowln unify(Xr, Xi)
@symshow   unify(Xi, Xf)

println()
@symshowln unify(Xi, 2)
@symshowln unify(Xr, 2.0)
@symshowln unify(Xi, 2.0)
@symshowln unify(Xi, 2.5)

println()
@symshowln unify(match(Any), 1)
@symshowln unify(match(Any), X)
@symshowln unify(match(Any), Xi)

println()
@show unify(X, X)
@show unify(X, Y)
