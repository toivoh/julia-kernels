

load("flatten.jl")
load("kernels.jl")


code = quote
    A[] = B.*C + D
end

symbols = HashTable{Symbol,SymEntry}()
flat_code = {}
receive = ex->append!(flat_code, {ex})
context = Context(symbols, receive)

value = flatten(context, code)

print_code(flat_code)
println("value = $value")
print_context(context)



#body = expr(:block, flat_code)

#indvars = gensym(32) # just some number of dims that should be enough
indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

nd = 2

body = wrap_kernel_body(flat_code, indvars[1:nd])

@eval function kernel(A::Array, B::Array, C::Array, D::Array)
    shape = size(A)
    $body
end

A = Array(Float, (2,3))
B = [1 2 3
     4 5 6]
C = [1 0 1
     0 1 0]
D = [ 0  0  0
     10 10 10]
kernel(A, B, C, D)

println("A =\n$A")
