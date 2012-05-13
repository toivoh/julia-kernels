
load("unify/unify.jl")
load("utils/req.jl")
req("unify/test/symshow.jl")

let
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

    Xi = pvar(Int, :Xi)
    Xa = pvar(Array, :Xa)
    Xv = pvar(Vector, :Xv)
    Xm = pvar(Matrix, :Xm)
    println()
    @symshow unify(Xi, {1,2})
    @symshowln unify(Xa, {1,2})
    @symshowln unify(Xv, {1,2})
    @symshow unify(Xm, {1,2})

    println()
    Xai = pvar(Array{Int}, :Xai)
    # todo: Should this work? And convert the cell Array to an Int Array
    @symshow   unify(Xai, {1,2})
    @symshowln unify(Xai, [1,2])
    @symshowln unify(Xa, [1,2,X])
    # todo: Should this work? And force X to be an Int.
    @symshowln unify(Xai, [1,2,X])
end