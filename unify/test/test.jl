
load("unify/unify.jl")

macro symshow(call)
    @expect is_expr(call, :call)
    args = call.args
    @expect length(args)==3
    op, x, y = tuple(args...)
    quote
#        @show ($call)
#        @show ($op)($y,$x)
        print($string(call))
        print("\t= ",    ($call))
        println(",\tsym = ", ($op)($y,$x))
    end
end

macro symshowln(call)
    @expect is_expr(call, :call)
    args = call.args
    @expect length(args)==3
    op, x, y = tuple(args...)
    quote
#        @show ($call)
#        @show ($op)($y,$x)
        println($string(call))
        println("\t= ",    ($call))
        println("sym\t= ", ($op)($y,$x))
    end
end


@pvar X Y

println()
@show restrict(Int, 1)
@show restrict(Float, 1)
@show restrict(Int, X)
@show restrict(None, X)

println()
@show Xr = restrict(Real, X)
@show Xi = restrict(Int, X)
@show Xf = restrict(Float, X)
@show restrict(Int, Xr)
@show restrict(Int, Xi)
@show restrict(Int, Xf)

println()
@show pvar(:Z)
@show pvar(Int, :Z)
@show pvar(None,:Z)
@show pvar(Any, :Z)

println()
@symshow unify(X, 3)
@symshowln unify(X, (4, "hej"))

println()
@show    unify(anyvalue, anyvalue)
@symshow unify(anyvalue,     1)
@symshow unify(match(Real),  1)
@symshow unify(match(Int),   1)
@symshow unify(match(Float), 1)
@symshow unify(nonevalue,    1)

println()
@show      unify(match(Real),  match(Real))
@symshowln unify(match(Real),  match(Int))
@symshow   unify(match(Float), match(Int))

println()
@symshowln unify(Xr, Xi)
@symshow   unify(Xi, Xf)

println()
@symshow unify(Xi, 2)
@symshow unify(Xr, 2.0)
@symshow unify(Xi, 2.0)
@symshow unify(Xi, 2.5)

println()
@symshow   unify(anyvalue, 1)
@symshow   unify(anyvalue, X)
@symshowln unify(anyvalue, Xi)

println()
@show unify(X, X)
@show unify(X, Y)

Yi = restrict(Int, Y)
println()
@show unify(X, Xi)
@show unify(Y, Xi)
@show unify(Yi, Xr)
@show unify(Yi, Xi)
@show unify(Yi, Xf)

