
load("utils/req.jl")
req("unify/unify.jl")
req("prettyshow/prettyshow.jl")

type NodeType
    kind::Symbol
end

show(io, t::NodeType) = print(io, t.kind)


pshow(io::PrettyIO, t::Tuple) = pshow_comma_list(io, {t...}, "\n(", ")\n")



calltype, reftype, inputtype = map(NodeType, (:call, :ref, :input))

callnode(args...) = tuple(calltype, args...)
refnode(args...) = tuple(reftype, args...)
inputnode(arg) = tuple(inputtype, arg)

#X = A.*B .+ C

A, B, C = map(inputnode, (:A,:B,:C))
AB = callnode(:(.*), A, B)
X = callnode(:(.+), AB, C)

pprintln(X)
 

