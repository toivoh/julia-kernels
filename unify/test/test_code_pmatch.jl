
load("utils/req.jl")
load("unify/pmatch.jl")
req("prettyshow/prettyshow.jl")

function show_code_pmatch(p)
    println()
    println("pattern = ", p)
    c=code_pmatch(p,:x)
    println("vars = ", c.vars)
#    println("code:")
#    foreach(x->println("\t", x), c.code)
    pprintln(expr(:block, c.code))
end

@pvar X, Xi::Int

show_code_pmatch(1)
show_code_pmatch(X)
show_code_pmatch(Xi)
show_code_pmatch((1,X))
show_code_pmatch((X,X))

println()
# ex=code_ifmatch(:(let (pvar(:X),1)=(2,1)
#     print("X = ", X)
# end))
# pprintln(ex)

@ifmatch let (pvar(:X), 1)=(2,1)
    println("X = ", X)
end

