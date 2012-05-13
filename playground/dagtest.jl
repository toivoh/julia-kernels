
load("utils/req.jl")
req("unify/unify.jl")
req("prettyshow/prettyshow.jl")


pshow(io::PrettyIO, t::Tuple) = pshow_comma_list(io, {t...}, "\n(", ")")



callnode(args...) = tuple(:call, args...)
refnode(args...) = tuple(:ref, args...)
inputnode(arg) = tuple(:input, arg)

#X = A.*B .+ C

A, B, C = map(inputnode, (:A,:B,:C))
AB = callnode(:(.*), A, B)
X = callnode(:(.+), AB, C)

pprintln(X)
 

