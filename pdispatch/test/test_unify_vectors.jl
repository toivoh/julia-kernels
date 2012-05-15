
load("pdispatch/pmatch.jl")
load("utils/req.jl")
req("utils/utils.jl")

let
    @pvar X, Y, Z
    
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
    @symshowln unify({1,X,Y}, {X,Y,1})
    @symshowln unify({1,X,Y}, {X,Y,2})
    @symshowln unify({1,Y,X}, {X,Z,Y})
    @symshowln unify(X, {1,X})

    println()
    @pvar Xi::Int, Xa::Array, Xv::Vector, Xm::Matrix
    @symshowln unify(Xi, {1,2})
    @symshowln unify(Xa, {1,2})
    @symshowln unify(Xv, {1,2})
    @symshowln unify(Xm, {1,2})

    println()
    @pvar Xai::Array{Int}
    @symshowln unify(Xai, {1,2})
    @symshowln unify(Xai, [1,2])
    @symshowln unify(Xa, [1,2,X])

    # consider: Should this work? And force X to be an Int.
    @symshowln unify(Xai, [1,2,X])
end
