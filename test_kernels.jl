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
        A[] = B.*C + D
    end
    tk = toc()
    (ta, tmk, tfor, tk)
end

timeit(1000)
