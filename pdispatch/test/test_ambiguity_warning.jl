
load("utils/req.jl")
load("pdispatch/pdispatch.jl")

## should work ##

# right order: shouldn't give a warning
@pattern r(x::Int,y::Int) = 1
@pattern r(x::Int,y) = 2
@pattern r(x,y::Int) = 3

# no finite unification ==> ok
@pattern r2(x,{1,x}) = 2
@pattern r2(y,y)     = 3

@pattern r3({x,y},{z,w}) = 1
@pattern r3(x,{y,z}) = 2
@pattern r3({x,y},z) = 3

@pattern r4(1,x,y::Int) = 2
@pattern r4(2,x::Int,y) = 3

#@pattern r5(x::None, y) = 2 # never matches ==> error
#@pattern r5(x, y::Int) = 3

## should warn ##

# should warn about g(::Int,::Int)
@pattern f1(x::Int,y) = 2
@pattern f1(x,y::Int) = 3

@pattern f2({1,x},y) = 2
@pattern f2(z,{2,w}) = 3

@pattern f3(x::Union(Int,String)) = 2
@pattern f3(x::Real) = 3

@pattern f4(x,2) = x
@pattern f4(1,y) = y

@pattern f6(y,{x,x},{y,y}) = 2
@pattern f6(y,y,z) = 3

@pattern f7(x,y,1,x,y) = 2
@pattern f7(x,y,x,y,1) = 3
