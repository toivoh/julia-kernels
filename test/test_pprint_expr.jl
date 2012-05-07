
load("utils/prettyprint.jl")

ex = :( function pprint(io::PrettyIO, ex::Expr)
    pprint(io, ex.head, "(")
    let io=subblock(io)
        for (arg, k) in enumerate(ex.args)
            pprint(io, arg)
            if k < length(ex.args)
                pprint(io, ", ")
            end
        end
    end
    pprint(io, ")")
end )

pprint(ex)
