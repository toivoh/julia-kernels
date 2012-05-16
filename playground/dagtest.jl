
load("utils/req.jl")
req("prettyshow/prettyshow.jl")

#req("pdispatch/pdispatch.jl")
load("pdispatch/pdispatch.jl")
load("pdispatch/ifmatch.jl")


pshow(io::PrettyIO, t::Tuple) = pshow_comma_list(io, {t...}, "\n(", ")")

callnode(args...) = tuple(:call, args...)
refnode(args...) = tuple(:ref, args...)
inputnode(arg) = tuple(:input, arg)
scatternode(arg) = tuple(:scatter, arg)

@pattern scprop(scatternode(s)) = propsc(s)
@pattern function scprop(node::Tuple) 
    tuple(node[1:2]..., {scprop(arg) for arg in node[3:end]}...)
end

@pattern function propsc(callnode(op, arg1, arg2))
    callnode(op, propsc(arg1), propsc(arg2))
end
@pattern propsc(inputnode(name)) = refnode(inputnode(name), :(...))
@pattern function propsc(node:Tuple)
    tuple(node[1], {scatterprop(scatter(arg)) for arg in node[2:end]}...)
end



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



pprintln()
spex = scprop(scatternode(X))
pprintln(spex)
