
load("utils/req.jl")
req("utils/failexpect.jl")
req("dag/pshow_dag.jl")
req("tangle.jl")
req("midsection.jl")
req("julia_backend.jl")


code = :( let
    dest[...] = scatter(A.*B + C)
    dest2[...] = A[scatter(B)]
end )

rawdag = tangle(code.args[1])
println("Raw DAG:")
pprintln(rawdag)

sdag = scatter_propagated(rawdag)
println("\nScattered DAG:")
pprintln(sdag)

edag = expand_ellipsis_indexing(sdag, [:i,:j])
println("\n[...] expanded:")
pprintln(edag)

println("\nuntangled:")
print_list(untangle(edag)[2])
