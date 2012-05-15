
load("utils/req.jl")
req("prettyshow/prettyshow.jl")

load("pdispatch/pmatch.jl")


function show_code_pmatch(p,vars::PVar...)
    println()
    println("pattern = ", p)

    d = Dict()
    for var in vars
        d[var.name] = var
    end

    c = PMContext(d)
    code_pmatch(c, p,:x)
    println("vars = ", c.vars)
#    println("code:")
#    foreach(x->println("\t", x), c.code)
    pprintln(expr(:block, c.code))
end

@pvar X, Xi::Int

show_code_pmatch(1)
show_code_pmatch(X, X)
show_code_pmatch(Xi, Xi)
show_code_pmatch((1,X), X)
show_code_pmatch((X,X), X)


c = RPContext()
@showln pattern = recode_pattern(c, :(X,1,value(X),X))
