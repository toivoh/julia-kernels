
load("utils/namespace.jl")

show(scanvars(quote
    x::Int
    y
    z=1
    local w::Float
    end))