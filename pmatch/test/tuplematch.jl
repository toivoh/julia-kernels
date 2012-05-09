
load("pmatch/pmatch.jl")

#X = pvar(:X)
@pvar X Y Z

P = (:a, X, :b)
s = (:a, :b, :b)

@show m = pmatch(P, s)

@show m2 = pmatch((X, :b), (:a, Y))
@show m3 = pmatch((X, Z), (:a, Y))

@show m4 = pmatch((:a,)~X, (:a,:b,(:q,:z)))
@show m5 = pmatch((:a,)~X~(:z,), (:a,:b,:z))
@show m6 = pmatch(X~(:z,), (:a,:b,:z))

