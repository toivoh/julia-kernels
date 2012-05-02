
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

println(cr(c,1), " ", cr2(c,1))
println(cr(c,2), " ", cr2(c,2))
println(cr(c,1), " ", cr2(c,1))

println()
println(cr(c,(2,3)))
println(cr(c,"hej")
