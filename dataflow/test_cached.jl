
load("utils.jl")

code = :(function f(x)
    x^2
end)

c = wrap_cached(code)
print(c)