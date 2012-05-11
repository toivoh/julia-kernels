
load("unify/unify.jl")
load("utils/req.jl")
req("unify/test/symshow.jl")

@pvar X Y

@show X
@show pvar(Int, :Z)
@show pvar(Any, :Z)
@show pvar(None, :Z)

println()
@show match(Any)
@show match(Int)
@show match(None)

println()
@show restrict(Int, 1)
@show restrict(Float, 1)
@show restrict(Int, X)
@show restrict(None, X)

println()
@show Xr = restrict(Real, X)
@show Xi = restrict(Int, X)
@show Xf = restrict(Float, X)
@show restrict(Int, Xr)
@show restrict(Int, Xi)
@show restrict(Int, Xf)

println()
@show restrict(Real,  match(Real))
@show restrict(Real,  match(Int))
@show restrict(Int,   match(Real))
@show restrict(Int,   match(Float))

println()
@show      dintersect(match(Real),  match(Real))
@symshowln dintersect(match(Real),  match(Int))
@symshow   dintersect(match(Float), match(Int))
