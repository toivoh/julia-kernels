
load("utils/req.jl")
req("prettyshow/prettyshow.jl")

#req("pdispatch/pdispatch.jl")
load("pdispatch/pdispatch.jl")
load("pdispatch/ifmatch.jl")


pshow(io::PrettyIO, t::Tuple) = pshow_comma_list(io, {t...}, "\n(", ")")
pshow(io::PrettyIO, v::Vector) = pshow_comma_list(io, {v...}, "\n{", "}")

callnode(args...) = {:call, args...}
refnode(args...) = {:ref, args...}
inputnode(arg) = {:input, arg}
scatternode(arg) = {:scatter, arg}

@pattern scprop(scatternode(s)) = propsc(s)
@pattern function scprop(node::Vector) 
    {node[1:2]..., {scprop(arg) for arg in node[3:end]}...}
end

@pattern function propsc(callnode(op, arg1, arg2))
    opmap = {:.+ => :+, :.- => :-, :.* => :*, :./ => :/ }
    op = get(opmap, op, op) 
    callnode(op, propsc(arg1), propsc(arg2))
end
@pattern propsc(inputnode(name)) = refnode(inputnode(name), :(...))
@pattern function propsc(node::Vector)
    {node[1], {scatterprop(scatter(arg)) for arg in node[2:end]}...}
end



#X = A.*B .+ C

A, B, C = map(inputnode, (:A,:B,:C))
AB = callnode(:(.*), A, B)
X = callnode(:(.+), AB, C)

 

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



println()
spex = scprop(scatternode(X))
pshow(X)
println()
pshow(spex)
