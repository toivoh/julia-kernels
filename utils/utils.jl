

const doublecolon = @eval (:(::Int)).head

quoted_expr(ex) = expr(:quote, ex)
quoted_exprs(exprs) = { quoted_expr(ex) for ex in exprs }

quotevalue(val)     = expr(:quote, val)
quotevalues(values) = { quotevalue(val) for val in values }


quoted_tuple(t) = expr(:tuple, {t...})

is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))
function is_expr(ex, head::Symbol, nargs::Int)
    is_expr(ex, head) && length(ex.args) == nargs
end


# == @expect ==================================================================

fail_expect(predexpr) = error("Expected: ", string(predexpr))

default_code_checkexpect(ex) = :($ex ? nothing : fail_expect($quoted_expr(ex)))
code_checkexpect(ex)         = default_code_checkexpect(ex)

macro expect(args...)
    if !(1 <= length(args) <= 2)
        error("\n@expect: expected one or two arguments")
    end
    predexpr = args[1]
    if length(args) >= 2
        # explicit error message given
        message = args[2]
        msg_parts = is_expr(message, :tuple) ? message.args : {message}
        return :(($predexpr) ? nothing : ($expr(:call, :error, msg_parts...)))
    else # no explicit message
        return code_checkexpect(predexpr)
    end    
end


# == @[sym]show[ln] ===========================================================

macro show(ex)
    :(println(($string(ex)), "\t= ", $ex) )
end
macro showln(ex)
    :(println(($string(ex)), "\n\t=", $ex) )
end

# todo: pull these two together!
macro symshow(call)
    @expect is_expr(call, :call)
    args = call.args
    @expect length(args)==3
    op, x, y = tuple(args...)
    quote
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
        println($string(call))
        println("\t= ",    ($call))
        println("sym\t= ", ($op)($y,$x))
    end
end


# == @assert_fails ============================================================

macro assert_fails(ex)
    @gensym err
    quote
        ($err) = nothing
        try
            ($ex)
            error("Didn't fail: ", ($quotevalue(ex)) )
        catch err
            ($err) = err
        end
        ($err)
    end
end


# == @setdefault ==============================================================

# macro setdefault(args...)
#     # allow @setdefault(refexpr, default)
#     if (length(args)==1) && is_expr(args[1], :tuple)
#         args = args[1].args
#     end
#     refexpr, default = tuple(args...)
macro setdefault(refexpr, default)
    @expect is_expr(refexpr, :ref)
    dict_expr, key_expr = tuple(refexpr.args...)
    @gensym dict key #defval
    quote
        ($dict)::Associative = ($dict_expr)
        ($key) = ($key_expr)
        if has(($dict), ($key))
            ($dict)[($key)]
        else
            ($dict)[($key)] = ($default) # returns the newly inserted value
        end
    end
end

