
load("pdispatch/pmatch.jl")
load("utils/req.jl")
req("utils/utils.jl")

@assert !isatomtype((Int,Any))
@assert !isatomtype(Any)
@assert !isatomtype(Pattern)
@assert !isatomtype(PVar)
@assert !isatomtype(NonePattern)
@assert !isatomtype(Array)
@assert !isatomtype(Vector)
@assert !isatomtype(Matrix)
@assert !isatomtype(Vector{Any})
@assert !isatomtype(Vector{Pattern})

@assert isatomtype(Int)
@assert isatomtype(Float)
@assert isatomtype(Vector{Float})