
load("utils/req.jl")
#req("unify/unify.jl")
#req("unify/pmatch.jl")
load("unify/pmatch.jl")
req("prettyshow/prettyshow.jl")


pshow(io::PrettyIO, t::Tuple) = pshow_comma_list(io, {t...}, "\n(", ")")

callnode(args...) = tuple(:call, args...)
refnode(args...) = tuple(:ref, args...)
inputnode(arg) = tuple(:input, arg)
scatternode(arg) = tuple(:scatter, arg)

# @pattern scprop(scatternode(s)) = propsc(s)
# @pattern function scprop(node) 
#     tuple(node[1:2]..., {scprop(arg) for arg in node[3:end]}...)
# end

# @pattern function propsc(callnode(op, arg1, arg2))
#     callnode(op, propsc(arg1), propsc(arg2))
# end
# @pattern propsc(inputnode(name)) = refnode(inputnode(name), :(...))
# @pattern function propsc(node)
#     tuple(node[1], {scatterprop(scatter(arg)) for arg in node[2:end]}...)
# end


function scatterprop(node)
    newnode::Any
    if !@ifmatch let scatternode(s)=node
        newnode = propscatter(s)
    end
        newnode = tuple(node[1:2]..., 
                        {scatterprop(arg) for arg in node[3:end]}...)
    end
    newnode
end

function propscatter(node)
    newnode::Any
    if !@ifmatch let callnode(op, arg1, arg2)=node
        newnode = callnode(op, propscatter(arg1), propscatter(arg2))
    end
        if !@ifmatch let inputnode(name)=node
            newnode = refnode(inputnode(name), :(...))
        end
            newnode = tuple(node[1], 
                        {scatterprop(scatter(arg)) for arg in node[2:end]}...)
        end
    end
    newnode
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
spex = scatterprop(scatternode(X))
pprintln(spex)


mt_scprop = PatternMethodTable()
#add(mt_scprop, :(scatternode(s)), :(propsc(s)))
add(mt_scprop, :(scatternode(s)), quote
    println("nlk")
    propsc(s)
end)
add(mt_scprop, :(node), 
    quote
        tuple(node[1], {scprop(arg) for arg in node[2:end]}...)
    end)

println()
ex = code_pattern_dispatch(mt_scprop, :scprop)
pprintln(ex)

eval(ex)


mt_propsc = PatternMethodTable()
add(mt_propsc, :( callnode(op, arg1, arg2)), :(
        callnode(op, propsc(arg1), propsc(arg2)) ))
add(mt_propsc, :( (inputnode(name)) ), :( refnode(inputnode(name), :(...)) ))
add(mt_propsc, :(node), :(
        tuple(node[1],{scatterprop(scatter(arg)) for arg in node[2:end]}...) ))

ex2 = code_pattern_dispatch(mt_propsc, :propsc)
eval(ex2)

# @pattern function propsc(callnode(op, arg1, arg2))
#     callnode(op, propsc(arg1), propsc(arg2))
# end
# @pattern propsc(inputnode(name)) = refnode(inputnode(name), :(...))
# @pattern function propsc(node)
#     tuple(node[1], {scatterprop(scatter(arg)) for arg in node[2:end]}...)
# end


pprintln()
spex2 = scprop(scatternode(X))
pprintln(spex2)
