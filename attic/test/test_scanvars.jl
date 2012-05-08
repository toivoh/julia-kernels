
load("utils/namespace.jl")

showall(scanvars_let(:(let arg1, arg2::Int, arg3=1, arg4::Int=2, arg5=(gl=1)
    a
    b::Int
    c=1
    d::Int = 2
    local e
    local f::Int
    local g=1
    local h::Int = 2

    x, y::Float = 1, 2
    begin
        z=3
    end
    let q=1
        local f::String="f"
        r::Int = 3
    end

    k = :k
    local k::Symbol

    function f(x)
        local e
    end
    f(x,y) = (local z=x*y)

    abstract S
    abstract T <: S
    type U
        x::Uint
        y::Uint
    end
    type V <: T
        z::String
    end
end)))
