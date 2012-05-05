
load("utils/namespace.jl")

ex = namespace(:nspace, :(let
# @namespace nspace let
    const x=3
    f(x) = x^2
    
end
))

if false
let
    type T
    end
    T
end

let
    type T
    end
    T()
end
end


#if false
@namespace nspace let
#ex = namespace(:nspace, :(let
    const x=3
    f(x) = x^2
    function g(x, y)
        x*y
    end
    abstract R
    type T<:R
        x::Int
        T(x) = new(x^2)
    end
    typealias S T    
end
#))
#end

@assert nspace.x == 3
@assert nspace.f(3) == 9
@assert nspace.g(2,3) == 6
nspace.R::AbstractKind
@assert nspace.T <: nspace.R
#@assert nspace.T(5).x == 25
assert is(nspace.T, nspace.S)

