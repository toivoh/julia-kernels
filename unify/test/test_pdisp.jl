
load("utils/req.jl")
load("unify/pmatch.jl")
req("prettyshow/prettyshow.jl")

#@pattern f(1) = 42
#@pattern f(x) = x

m1 = patmethod(:(1,), :(42))
m2 = patmethod(:(x,), :(x))

c1=code_pmethod_closure(m1)
c2=code_pmethod_closure(m2)

println(c1)
println(c2)

f1 = eval(c1)
f2 = eval(c2)

mtable = PatternMethodTable(:f)
#add(mtable, patmethod(:(1,), :(42)))
#add(mtable, patmethod(:(x,), :(x)))
add(mtable, (@patmethod f(1) = 42))
add(mtable, (@patmethod f(x) = x))

f = (args...)->(dispatch(mtable, args))

println()
@show f(1)
@show f(2)
@show f(3)