


load("kernels.jl")





code = quote
    A[...] = B.*C + D
end


nd = 2
staged = true


function make_k(code, nd)
    flat_code, arguments = flatten_kernel_tangle(code)

    #indvars = gensym(32) # just some number of dims that should be enough
    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

    fdef = wrap_kernel(arguments, flat_code, indvars[1:nd], staged)
    #fdef = make_kernel(nd, code)

    kernel = eval(fdef)

    kernel, arguments
end

macro kern(code)
    kernel, arguments = make_k(code, nd)
    expr(:call, kernel, arguments...)    
end


#kernel, arguments = make_k(code, nd)
fdef, arguments = make_kernel(code, nd)
kernel = eval(fdef)


A = Array(Float, (2,3))
B = [1 2 3
     4 5 6]
C = [1 0 1
     0 1 0]
D = [ 0  0  0
     10 10 10]
kernel(A, B, C, D)

println("A =\n$A")

@kernel 2 begin
    A[...] = B.*C + D
end
