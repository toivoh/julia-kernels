
load("unify/unify.jl")
load("utils/req.jl")
req("unify/test/symshow.jl")

@show @pvar X Y
@show X

@show pvar(Int, :Z)

