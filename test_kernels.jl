load("kernels.jl")

A = Array(Float, (2,3))
B = [1 2 3
     4 5 6]
C = [1 0 1
     0 1 0]
D = [ 0  0  0
     10 10 10]

@kernel 2 begin
    A[] = B.*C + D
end

println("A =\n$A")
