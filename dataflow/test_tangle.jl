load("tangle.jl")


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[] = 2A
end

value, dag, context = tangle(code)

println("value = $value")
print_context(context)

println()
println("untangled:")
untangled = untangle(context.dag)
print_list(untangled)
