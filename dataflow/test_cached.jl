
load("utils.jl")

type PlainContext <: Context
    cache::Cache
    PlainContext() = new(Cache())
end

# code = :(function f(c::Context, x::Int)
#     x^2
# end)

code = :(f(c::Context, x::Int) = x^2)

c = wrap_cached(code)
print(c)

@cached function cr(c::Context, x)
    randi(100)
end
@cached function cr2(c::Context, x)
    randi(100)
end


c = PlainContext()

println()
@show cr(c,1), cr2(c,1)
@show cr(c,2), cr2(c,2)
@show cr(c,1), cr2(c,1)

println()
@show cr(c,(2,3))
@show cr(c,"hej")
        