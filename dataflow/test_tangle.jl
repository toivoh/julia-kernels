load("twine.jl")


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[] = 2A
end

symbols = Dict{Symbol,Node}()
context = Context(symbols)

value = twine(context, code)

println("value = $value")
print_context(context)
