
load("utils/prettyshow.jl")

ex = :( function pprint(io::PrettyIO, ex::Expr)
    if contains([:(=), :(.), doublecolon], head) && nargs==2
        pprint(subblock(io), args[1], string(head), args[2])
    else
        pprint(io, ex.head, "(")
        let io=subblock(io)
            for (arg, k) in enumerate(ex.args)
                pprint(io, arg)
                if k < length(ex.args)
                    pprint(io, ", ")
                end
            end
        end
        return pprint(io, ")")
    end

    try
        a
    end
    try
        a
    catch x
        b
    end

    let
        x+=1
    end
    let x=1
        x+=1
    end
    let x=1,y=2
        x+=1
    end

    begin
        a=1
        b=2
    end

    abstract R<:S
    type T
        x::Int
    end
    typealias P T

    type Q{T}
        q::Q
    end
    while 1 < x < 5
        x += 1
    end
    local x::Int
    local x,y,z
    global y=4.5
    const z=3
    f=x->x^2
end )

pprint(ex)
