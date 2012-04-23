
# -- Dimensions ---------------------------------------------------------------

type PartialDimension
    name::Symbol
end

typealias Dimension Union(PartialDimension, Int)

#show(d::PartialDimension) = print("dimension(:$(d.name))")
show(d::PartialDimension) = print(d.name)

function broadcast_dim(n, m)
    if (n == m) || (n == 1)
        return m
    elseif m == 1
        return n
    end
    error("Cannot broadcast together dimensions: $n != $m")
end

function broadcast_shape(s::(Dimension...), t::(Dimension...))
    (ns, nt) = (length(s), length(t))
    if ns < nt 
        return broadcast_shape(t, s)
    elseif ns > nt
        return tuple(broadcast_shape(s[1:nt], t)..., s[(nt+1):ns]...)
    end
    return map(broadcast_dim, s, t)
end

## Factory ##
dimension(x::Int) = x
dimension(name::Symbol) = PartialDimension(name)


# == PartialArray =============================================================

# Array depending on yet unknown values
abstract PartialArray{T,N} <: AbstractArray{T,N} 

# required fields: shape

size(A::PartialArray) = A.shape
size{T,N}(A::PartialArray{T,N}, d) = (d <= N ? A.shape[d] : 1)

show{T,N}(A::PartialArray{T,N}) = print(A.name)


peel(args::Tuple) = map(peel, args)
peel(args...) = peel(args)

#uinds = gensym(32) # just some number of dims that should be enough
uinds = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

# -- InputArray ---------------------------------------------------------------

type InputArray{T,N} <: PartialArray{T,N}
    name::Symbol
    shape::(Dimension...)
    
    #todo: check length(shape) == N!
end

## Factory ##
input_array(name, T, shape) = InputArray{T,length(shape)}(name, shape)
input_array(name, T, shape...) = input_array(name, T, shape)

peel(A::InputArray) = expr(:ref, A.name, uinds[1:ndims(A)]...)


# -- OuputArray ---------------------------------------------------------------

#type OutputArray{T,N} <: PartialArray{T,N}
type OutputArray{T,N}  <: AbstractArray{T,N} # don't want outputs as inputs
    name::Symbol
    shape::(Dimension...)

    writes::Vector

    OutputArray(name, shape) = new(name, shape, {})
end


## Factory ##
output_array(name, T, shape) = OutputArray{T,length(shape)}(name, shape)
output_array(name, T, shape...) = output_array(name, T, shape)


function assign{T,N}(dest::OutputArray{T,N}, A::PartialArray{T,N})
    ref = expr(:ref, dest.name, uinds[1:ndims(dest)]...) 
    a = peel(A)
    write_op = :( ($ref) = $a )
    append!(dest.writes, {write_op})
end


# -- KernelArray --------------------------------------------------------------

# partial array composed of partial elements
type KernelArray{T,N} <: PartialArray{T,N}
    # inds?
    ex::Expr

    shape::(Dimension...)
end

KernelArray{T}(ex, ::Type{T}, shape) = KernelArray{T,length(shape)}(ex, shape)

peel(A::KernelArray) = A.ex


# -- PartialArray math --------------------------------------------------------

function .*{TA,TB}(A::PartialArray{TA}, B::PartialArray{TB})
    shape = broadcast_shape(size(A), size(B))
    T = promote_type(TA, TB)    
    
    (a, b) = peel(A, B)
    ex = :($a*$b)  # ($a).*($b) instead?
    KernelArray(ex, T, shape)
end



# -- Test code ----------------------------------------------------------------

if false
    VType = Float32
    
    n = dimension(:n)
    m = dimension(:m)
    
    A = input_array(:A, VType, (n,m))
    B = input_array(:B, VType, (n,m))
    dest = output_array(:dest, VType, (n,m))
    
    C = A.*B
    dest[] = C
end


