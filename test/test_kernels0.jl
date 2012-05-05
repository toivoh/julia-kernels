load("kernels.jl")


dest1 = Array(Int, (2,3))
dest2 = Array(Int, (2,3))
B = [1 2 3
     4 5 6]
C = [1 0 1
     0 1 0]
D = [ 0  0  0
     10 10 10]

# code = quote
#     A = B.*C + D
#     dest1[...] = A
#     dest2[...] = A + C
# end
# ex = code_kernel(code)
# eval(ex)

@kernel let
    A = B.*C + D
    dest1[...] = A
    dest2[...] = A + C
end

function f(B,C,D)
    A = B.*C + D
    dest1 = A
    dest2 = A + C
    (dest1, dest2)
end
dest1f, dest2f = f(B,C,D)

println("kernel:     dest1 =\n$dest1")
println("Array ops:  dest1 =\n$dest1f")
println()
println("kernel:     dest2 =\n$dest2")
println("Array ops:  dest2 =\n$dest2f")
println()
