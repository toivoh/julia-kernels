
load("utils/req.jl")
req("utils/failexpect.jl")
req("dag/pshow_dag.jl")
req("tangle.jl")
req("midsection.jl")


code = :( let
    dest[...] = scatter(A.*B + C)
end )

rawdag = tangle(code.args[1])
println("Raw DAG:")
pprintln(rawdag)

sdag = scatter_propagated(rawdag)
println("\nScattered DAG:")
pprintln(sdag)
