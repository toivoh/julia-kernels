load("tangle.jl")
load("transforms.jl")

code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[...] = 2A
end

value, dag, context = tangle(code)
order!(dag)

print_context(context)
println("value = $value")


println()
println("untangled:")
untangled = untangle(context.dag)
print_list(untangled)


# dag2, c2 = rewrite_dag(dag, ScatterVisitor())
# order!(dag2)
# println("\ndag2 untangled:")
# print_untangled(dag2)

dag2 = scattered(dag)
println("\nscattered (untangled):")
print_untangled(dag2)

dag3 = count_uses(dag2)
println("\nfanout nodes named (untangled):")
print_untangled(dag3)

