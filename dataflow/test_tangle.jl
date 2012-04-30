load("tangle.jl")
load("transforms.jl")

code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[] = 2A
end

value, dag, context = tangle(code)
order!(dag)

print_context(context)
println("value = $value")


println()
println("untangled:")
untangled = untangle(context.dag)
print_list(untangled)
