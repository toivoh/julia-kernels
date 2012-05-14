
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
 

for node in {A, B, C, AB, X}
    @ifmatch let (:input, name)=node
        println("matched: name = ", name)
        println("\ton node = ", node)
    end
    @ifmatch let (:call, op, arg1, arg2)=node
        println("matched: op=$op, arg1=$arg1, arg2=$arg2")
        println("\ton node = ", node)        
    end
end
