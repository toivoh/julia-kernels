load("kernels.jl")
load("print_dag.jl")

# code = quote
#     A = B.*C + D[j,i]
#     dest[2i, 2j] = A
#     dest2[...] = 2A
# end
code = :(let
    A = B.*C + D
    X = A + C
    dest1[...] = A
    dest2[...] = X
end)


rawdag = tangle(code.args[1])[2]

kernelargs = collect_arguments(rawdag)
gendag = general_transform(rawdag)


pprint(rawdag)
