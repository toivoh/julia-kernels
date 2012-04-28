load("tangle.jl")


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[] = 2A
end

symbols = Dict{Symbol,Node}()
context = Context(symbols)

value = tangle(context, code)

println("value = $value")
print_context(context)
