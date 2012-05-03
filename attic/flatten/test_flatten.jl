
load("flatten.jl")


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
    dest2[] = 2A
end

symbols = Dict{Symbol,SymEntry}()
flat_code = {}
receive = ex->append!(flat_code, {ex})
context = Context(symbols, receive)

value = flatten(context, code)

print_code(flat_code)
println("value = $value")
print_context(context)
