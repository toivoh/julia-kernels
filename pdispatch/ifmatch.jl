

load("utils/req.jl")
req("utils/utils.jl")
req("pdispatch/pmatch.jl")


# -- @ifmatch -----------------------------------------------------------------

macro ifmatch(ex)
    code_ifmatch_let(ex)
end
function code_ifmatch_let(ex)
    @expect is_expr(ex, :let)
    body = ex.args[1]
    #matches = ex.args[2:end]
    @expect length(ex.args) == 2
    match = ex.args[2]

    @expect is_expr(match, :(=), 2)

    pattern, valex = match.args[1], match.args[2]
    code_ifmatch_let(pattern, valex, body)
end

function code_ifmatch_let(pattern, valex, body)
    valname = gensym("value")
    
    rpc = RPContext()
    pattern = recode_pattern(rpc, pattern)
    pattern = eval(pattern)

    pmc=PMContext(rpc)
    code_pmatch(pmc, pattern,valname)
    push(pmc.code, :true)
#    foreach(pprintln, pmc.code)

    varnames = {kv[2].name for kv in pmc.vars}
#    pmatch

    :(
        let ($valname)=($valex)
            local ($varnames)
            if let
                ($pmc.code...)
            end
                ($body)
                true
            else
                false
            end
        end
    )
end
