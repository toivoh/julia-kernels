load("tangle.jl")
load("transforms.jl")

# code = quote
#     A = B.*C + D[j,i]
#     dest[2i, 2j] = A
#     dest2[...] = 2A
# end
code = quote
    A = B.*C + D
    X = A + C
    dest1[...] = A
    dest2[...] = X
end

value, dag, context = tangle(code)
order!(dag)

print_context(context)
println("value = $value")


println()
println("untangled:")
untangled = untangle(context.dag)
print_list(untangled)


# dag2 = scattered(dag)
# println("\nscattered (untangled):")
# print_untangled(dag2)

# dag3 = count_uses(dag2)
# println("\nfanout nodes named (untangled):")
# print_untangled(dag3)

bottom2 = scattered(dag.bottom)
println("\nscattered (untangled):")
print_untangled(DAG(bottom2))

bottom3 = count_uses(bottom2)
println("\nfanout nodes named (untangled):")
print_untangled(DAG(bottom3))
