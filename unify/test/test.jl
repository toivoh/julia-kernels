
load("unify/pmatch.jl")

X, Y = pvar(:X), pvar(:Y)

@show m1 = unify(X, 3)
@show m2 = unify(X, (4, "hej"))
@show m3 = unify(match(Int), 3)
@show m4 = unify(match(String), 3)

println()
@show unify((X, :b, :c), (:a, :b, :c))
@show unify((X, :b, :c), (:a, :a, :b, :c))
@show unify((X, :b, :c), (:a, :b, Y))
@show unify((:a, (X, :c)), (:a, (:b, :c)))

println()
@show unify((X, Y), (Y, :a))
println()
@show unify(X, (1, 2))
@show unify(X, (1, X))

println()
@show unify(match(Real), match(Int))
@show unify(match(Int), match(Real))
@show unify(match(Float), match(Int))

R = pvar(Real, :R)
I = pvar(Integer, :I)
F = pvar(Float, :F)

println()
@show unify(R, match(Int))
@show unify(I, match(Int))
@show unify(F, match(Int))
@show unify(F, match(Real))

println()
@show unify(R, I)
@show unify(I, R)
@show unify(I, F)
