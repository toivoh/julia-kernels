
# -- ArgumentArray ------------------------------------------------------------


type ArgumentArray{T,N} <: AbstractArray{T,N}
    name::String
    writes::Vector

    ArgumentArray(name::String) = new(name, {})
end

ArgumentArray{T}(::Type{T}, N::Int, name::String) = ArgumentArray{T,N}(name)

show{T,N}(A::ArgumentArray{T,N}) = print(A.name)
# function show{T,N}(A::ArgumentArray{T,N})
#     print("ArgumentArray{$T,$N}(\"$(A.name)\")")
# end



# === KernelExpr ==============================================================

abstract KernelExpr{T}

# -- Index --------------------------------------------------------------------

type Index <: KernelExpr{Int}
    name::String
end

show(i::Index) = print(i.name)


# -- KernelRef ----------------------------------------------------------------

type KernelRef{T} <: KernelExpr{T}
    source::ArgumentArray{T}
    inds::(KernelExpr...)
    
    function KernelRef(source::ArgumentArray{T}, inds::(KernelExpr...))
        if length(inds) != ndims(source); 
            error("Wrong number of indices!")
        end
        new(source, inds)
    end
end

show(ref::KernelRef) = print("$(ref.source)[$(ref.inds)]")

function KernelRef{T}(source::ArgumentArray{T}, inds::(KernelExpr...))
    KernelRef{T}(source, inds)
end

ref(A::ArgumentArray, inds::KernelExpr...) = KernelRef(A, inds)


# -- KernelOp -----------------------------------------------------------------

type KernelOp{T} <: KernelExpr{T}
    op::Function
    args::Tuple
end

KernelOp(T, op, args...) = KernelOp(T, op, args)
KernelOp{T}(::Type{T}, op, args) = KernelOp{T}(op, args)

show(op::KernelOp) = print("$(op.op)($(op.args))")

function *{Tx,Ty}(x::KernelExpr{Tx}, y::KernelExpr{Ty})
    T = promote_type(Tx, Ty)
    op = *
    args = (x, y)
    KernelOp(T, *, args)
end



function assign{T}(A::ArgumentArray{T}, x::KernelExpr{T}, inds::KernelExpr...)
    if length(inds) != ndims(A); error("Wrong number of indices!"); end
    write = (inds, x)
    append!(A.writes, {write})
end



# -- Test code ----------------------------------------------------------------

VType = Float32

i = Index("i")
j = Index("j")

A = ArgumentArray(VType, 2, "A")
B = ArgumentArray(VType, 2, "B")
dest = ArgumentArray(VType, 2, "dest")

a = A[j,i]
b = B[j,i]
c = a*b
dest[i,j] = c
 
