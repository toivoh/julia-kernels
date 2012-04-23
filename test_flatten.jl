
load("flatten.jl")


code = quote
    A = B.*C + D[j,i]
    dest[2i, 2j] = A
end

symbols = HashTable{Symbol,SymEntry}()
flat_code = {}
receive = ex->append!(flat_code, {ex})
context = Context(symbols, receive)

value = flatten(context, code)

println("code:")
for ex in flat_code; println("\t", ex); end

println("value = $value")
println("inputs  = $(context.inputs)")
println("outputs = $(context.outputs)")

println("symbols at end:")
for (k, v) in context.symbols
    println("\t$k = $v")
end
