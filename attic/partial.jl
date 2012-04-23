
peel(t::Tuple) = map(peel, t)

# macro peel(args...)
#     ex = :nothing
#     for arg in args
#         exi = :($arg = peel($arg))
#         ex = :($exi; $ex)
#     end
#     ex
# end

macro peel(args...)
    if length(args) < 1; error("@peel: at least one arg!"); end
    body = args[end]
    args = args[1:(end-1)]
    peels = {:(($arg) = peel($arg)) | arg in args }
    expr(:let, body, peels...)
end



abstract Partial{T}


# -- Input --------------------------------------------------------------------

type Input{T} <: Partial{T}
    name::Symbol
end

#show{T}(arg::Input{T}) = print("Input{$T}(:$(arg.name))")

index(name::Symbol) = Input{Int}(name)
input_array(T, N, name::Symbol) = Input{Array{T,N}}(name)

peel(arg::Input) = arg.name


# -- Operation ----------------------------------------------------------------

type Operation{T} <: Partial{T}
#    eval::Function
    ex::Expr
end

peel(op::Partial) = op.ex


function ref{T,N}(A::Partial{Array{T,N}}, inds::Partial...) 
#    Operation{T}(args->( peval(A, args)[peval(inds, args)...] ))
#    Operation{T}(ev->( ev(A)[ev(inds)] ))
#    Operation{T}(quote; $(peel(A)) [$(peel(inds))]; end)

#    @peel A inds Operation{T}(:( ($A)[$inds] ))
    @peel A inds Operation{T}( expr(:ref, A, inds...) )
end

function *{Tx,Ty}(x::Partial{Tx}, y::Partial{Ty})
    T = promote_type(Tx, Ty)
#    Operation{T}(ev->( ev(x)*ev(y) ))
#    Operation{T}(quote; $(peel(x)) * $(peel(y)); end)
    @peel x y Operation{T}(:( ($x)*($y) ))
end


# -- Output -------------------------------------------------------------------

type Output{T}
    writes::Vector
    name::Symbol
    Output(name::Symbol) = new({}, name)
end

#output_array(T, N, name) = Output{Array{T,N}}({}, name)
output_array{T}(::Type{T}, N, name) = Output{Array{T,N}}(name)

peel(arg::Output) = arg.name



function assign{T,N}(A::Output{Array{T,N}}, x::Partial{T}, inds::Partial...)
#    write_op = ev->( ev(A)[ev(inds)] = ev(x) )
#    write_op = quote $(peel(A)) [ $(peel(inds)) ] = $(peel(x)); end

#    write_op = @peel A x inds :( ($A)[($inds)...] = ($x) )
#    write_op = @peel A x inds :( ($A)[($inds...)] = ($x) )
    
    write_op = @peel A x inds begin
        ref = expr(:ref, A, inds...) 
        :( ($ref) = $x )
    end
    append!(A.writes, {write_op})
end


# -- Test code ----------------------------------------------------------------

VType = Float32

i = index(:i)
j = index(:j)

A = input_array(VType, 2, :A)
B = input_array(VType, 2, :B)
dest = output_array(VType, 2, :dest)

 

a = A[j,i]
b = B[j,i]
c = a*b
dest[i,j] = c


@eval f(dest,A,B,i,j) = ($dest.writes[1])


X = [1 2; 3 4]
d=zeros(2,2)
f(d,X,X,1,1)
