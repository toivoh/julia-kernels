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

# value, dag, context = tangle(code)
# dag2 = scattered(dag)
# dag3 = count_uses(dag2)
# order!(dag3)
# flat_code = untangle(dag3)

# arguments = append(get(dag3.symnode_names, :output, Symbol{}),
#                    get(dag3.symnode_names, :input,  Symbol{}))
 
# fdef, arguments = make_kernel(code, 2)

@kernel 2 begin
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

function timeit(n::Int)
    A = Array(Float, n, n)
    temp = Array(Float, n, n)
    B = rand(n, n)
    C = rand(n, n)
    D = rand(n, n)
    
    print("Array routines:     "); tic()
    B.*C + D
    ta = toc()

    print("For loops:          "); tic()
    for j=1:n,i=1:n
        temp[i,j] = B[i,j].*C[i,j]
    end
    for j=1:n,i=1:n
        A[i,j] = temp[i,j] + D[i,j]
    end
    tfor = toc()
    
    print("Handwritten kernel: "); tic()
    for j=1:n,i=1:n
        A[i,j] = B[i,j].*C[i,j] + D[i,j]
    end
    tmk = toc()

    print("Kernel:             "); tic()
    @kernel 2 begin
        A[...] = B.*C + D
    end
    tk = toc()
    (ta, tmk, tfor, tk)
end

timeit(1000)
