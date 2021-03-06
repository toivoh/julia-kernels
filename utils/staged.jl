function _jl_add_method(gf, an, at, body)
    argexs = { expr(symbol("::"), an[i], at[i]) | i=1:length(an) }
    def = quote
        let __F__=($gf)
            function __F__($(argexs...))
                $body
            end
        end
    end
    eval(def)
end

macro staged(fdef)
    if !isa(fdef,Expr) || !is(fdef.head,:function)
        error("@staged: expected method definition")
    end
    fname = fdef.args[1].args[1]
    argspec = fdef.args[1].args[2:]
    argnames = map(x->(isa(x,Expr) ? x.args[1] : x), argspec)
    qargnames = map(x->expr(:quote,{x}), argnames)
    fbody = fdef.args[2]
    @gensym gengf argtypes expander genbody
    quote
        let ($gengf)
            global ($fname)   # should be "outer"
            local ($expander)
            function ($expander)($(argnames...))
                $fbody
            end
            ($gengf)() = 0    # should be initially empty GF
            function ($fname)($(argspec...))
                ($argtypes) = typeof(tuple($(argnames...)))
                if !method_exists($gengf, $argtypes)
                    ($genbody) = apply(($expander), ($argtypes))
                    _jl_add_method($gengf, cell_1d($(qargnames...)),
                                   $argtypes, $genbody)
                end
                return ($gengf)($(argnames...))
            end
        end
    end
end

# example

@staged function nloops(dims::Tuple)
    names = map(x->gensym(), dims)
    ex = quote
        println(vcat($(names...)))
    end
    for i = 1:length(dims)
        ex = quote
            for ($names[i]) in dims[$i]
                $ex
            end
        end
    end
    ex
end
