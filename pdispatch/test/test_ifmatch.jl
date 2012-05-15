
load("pdispatch/ifmatch.jl")


@ifmatch let (X,1)=(2,1)
    println("X = ", X)
end

println()
for k=1:4
    if !@ifmatch let (X,value(k))=(1,2)
        println("k=$k: X=$X")
    end
        println("k=",k)
    end
end
