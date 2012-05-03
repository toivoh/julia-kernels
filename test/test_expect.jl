
load("utils/utils.jl")

macro evalcatch(ex)
    quote; let
        println($string(ex))
        try
            value = $ex
            println("  success; returned ", value)
        catch err
            println("  threw \"", err, '"')
        end
        println()
    end; end
end

@evalcatch @expect true
@evalcatch @expect false

@evalcatch @expect is_expr(:(x+y), :call)
@evalcatch @expect is_expr(1, :call)
@evalcatch @expect is_expr(1)