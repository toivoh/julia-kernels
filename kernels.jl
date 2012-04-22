load("partialarray.jl")
load("staged.jl")

# -- Test kernel construction -------------------------------------------------

function make_kernel_body(dest, sources)
    body = expr(:block, dest.writes)
    for k = 1:ndims(dest)
        i = uinds[k]
        body = :(
            for ($i) = 1:size(($dest.name), $k)
                $body
            end
        )
    end
    body
end

function make_kernel_function(dest, sources)
    body = make_kernel_body(dest, sources)
    args = append((dest.name,), map(arg->arg.name, sources)) 
    args = expr(:tuple, {args...})
    f = expr(:(->), args, body)
end

function make_kernel(dest, sources)
    eval(make_kernel_function(dest, sources))
end



# -- Test code ----------------------------------------------------------------


VType = Float32

n = dimension(:n)
m = dimension(:m)

A = input_array(:A, VType, (n,m))
B = input_array(:B, VType, (n,m))
dest = output_array(:dest, VType, (n,m))

C = A.*B
dest[] = C


f = make_kernel(dest, (A, B))


(ni, mi) = (2, 3)
Ai = [1 2 3; 4 5 6]
Bi = [1 0 1; 0 1 0]
desti = Array(VType, (ni,mi))
f(desti, Ai, Bi)
