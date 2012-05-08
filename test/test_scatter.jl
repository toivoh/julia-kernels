
load("utils/req.jl")
req("tangle.jl")
req("dag/pshow_dag.jl")

code = :( let
    dest[...] = scatter(A.*B + C)
end )

rawdag = tangle(code.args[1])
pprint(rawdag)