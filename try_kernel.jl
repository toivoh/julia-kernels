

load("flatten.jl")


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



body = expr(:block, flat_code)
@eval function kernel(A::Array, B::Array, C::Array, D::Array)
    shape = size(A)
    for j=1:shape[2], i=1:shape[1]
        print(i)
        readinput(X) = X[i,j]
        writeoutput(X,y) = X[i,j]=y
        $body
    end
end

A = Array(Float, (2,3))
B = [1 2 3
     4 5 6]
C = [1 0 1
     0 1 0]
D = [ 0  0  0
     10 10 10]
kernel(A, B, C, D)