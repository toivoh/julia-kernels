
load("utils/namespace.jl")

show(scanconsts_let(:(let a=5
    local k::Int
    local l=3
    n = 11
    m::Int = 3
    
    const x1=4
    const local y2=3
    local const z3=2
    f4(x)=x^2
    function f5(x,y)
        x*y
    end
    abstract U6
    abstract V7<:U6
    type S8; end
    type T9<:S8; end
    type P10{T9}; end
    type Q11{T9} <: P10{T9}; end
    typealias PInt12 P{Int}
    const h13 = x->(const x2=x^2; x2)    
    begin
        const c14=4
    end

    let d=34
        const e=6
    end
    g = x->(const x2=x^2; x2)
    for i=1:5
        const j=3
    end

    global const gl=4
    const global lg=5
    
end)))
