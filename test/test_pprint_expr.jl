
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
end )

pprint(ex)
