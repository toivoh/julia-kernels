
load("pdispatch/pmatch.jl")
load("utils/req.jl")
req("utils/utils.jl")

let
    @show @pvar X, Y
    
    @show X
    @show pvar(:Z, Int)
    @show pvar(:Z, Any)
    @show pvar(:Z, None)
    
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
    
    @pvar Xr::Real, Xi::Int, Xf::Float

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
end
