load("unify/unify.jl")

X, Y = pvar(:X), pvar(:Y)

@show unify(X, 3)
@show unify(X, (4, "hej"))

println()
@show restrict(Int, 1)
@show restrict(Float, 1)
@show restrict(Int, X)
@show restrict(None, X)

Xr = restrict(Real, X)
Xi = restrict(Int, X)
Xf = restrict(Float, X)

println()
@show unify(Xr, Xi)
@show unify(Xi, Xr)
@show unify(Xi, Xf)

println()
@show unify(Xi, 2)
@show unify(Xr, 2.0)
@show unify(Xi, 2.0)

println()
@show unify(Anything, 1)
@show unify(Anything, X)
@show unify(Anything, Xi)


# @showln m3 = unify(match(Int), 3)
# @showln m4 = unify(match(String), 3)

# println()
# @showln unify((X, :b, :c), (:a, :b, :c))
# @showln unify((X, :b, :c), (:a, :a, :b, :c))
# @showln unify((X, :b, :c), (:a, :b, Y))
# @showln unify((:a, (X, :c)), (:a, (:b, :c)))

# println()
# @showln unify((X, Y), (Y, :a))
# println()
# @showln unify(X, (1, 2))
# @showln unify(X, (1, X))

# println()
# @showln unify(match(Real), match(Int))
# @showln unify(match(Int), match(Real))
# @showln unify(match(Float), match(Int))

# R = pvar(Real, :R)
# I = pvar(Integer, :I)
# F = pvar(Float, :F)

# println()
# @showln unify(R, match(Int))
# @showln unify(I, match(Int))
# @showln unify(F, match(Int))
# @showln unify(F, match(Real))

# println()
# @showln unify(R, I)
# @showln unify(I, R)
# @showln unify(I, F)
