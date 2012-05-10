
load("unify/unify.jl")
load("utils/req.jl")
req("unify/test/symshow.jl")

@pvar X Y Z

@symshowln unify(X, {1,2})
@symshowln unify({X,2}, {1,2})
@symshowln unify({X,1}, {1,2})
@symshowln unify({1,X}, {1,2})
@symshowln unify({1,X}, {Y,2})
@symshowln unify({1,X}, {1,2,3})
@symshowln unify({1,X,Y}, {1,2,3})
@symshowln unify({1,X}, {1,{2,3}})

println()
@symshowln unify({1,X}, {X,Y})
@symshowln unify({1,X,Y}, {X,Y,Z})
@symshowln unify({1,Y,X}, {X,Z,Y})
@symshowln unify(X, {1,X})