load("partialarray.jl")
load("staged.jl")


quote_tuple(t) = expr(:tuple, {t...})
quote_expr(ex) = expr(:quote, ex)

# -- Test kernel construction -------------------------------------------------

function make_kernel_parts(dest, sources)
    body = expr(:block, dest.writes)
    for k = 1:ndims(dest)
        i = uinds[k]
        body = :(
            for ($i) = 1:size(($dest.name), $k)
                $body
            end
        )
    end

    args = append((dest.name,), map(arg->arg.name, sources)) 
    
    (args, body)
end

function make_kernel_function(dest, sources)
    args, body = make_kernel_parts(dest, sources)
    f = expr(:(->), quote_tuple(args), body)
end

function make_kernel(dest, sources)
    eval(make_kernel_function(dest, sources))
end
function make_staged_kernel(dest, sources)
    eval(make_staged_kernel_function(dest, sources))
end

function make_staged_kernel_function(dest, sources)
    args, body = make_kernel_parts(dest, sources)
    name = gensym("kernel")
    head = expr(:call, name, args...)

#    f = expr(:function, head, body)
    f = expr(:function, head, quote_expr(body))
    f = :(@staged $f)
    :($f; $name)
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
