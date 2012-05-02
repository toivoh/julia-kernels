
quote_expr(ex) = expr(:quote, ex)

is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))

macro expect(args...)
    if !(1 <= length(args) <= 2)
        error("\n@expect: expected one or two arguments")
    end
    predicate = args[1]
    if length(args) >= 2
        message = args[2]

        if is_expr(message, :tuple)
            msg_parts = message.args
        else
            msg_parts = {message}
        end
    else
        msg_parts = {"Expected: ", string(predicate)}
    end    
    :($predicate ? nothing : $(expr(:call, :error, msg_parts...)))
end

macro show(ex)
    :(println(($string(ex)), " = ", $ex) )
end

function expect_expr(ex, head::Symbol)
    @expect is_expr(ex, head) "expected expr(:$head,...), found $ex"
end

# macro setdefault(args...)
#     # allow @setdefault(refexpr, default)
#     if (length(args)==1) && is_expr(args[1], :tuple)
#         args = args[1].args
#     end
#     refexpr, default = tuple(args...)
macro setdefault(refexpr, default)
    expect_expr(refexpr, :ref)
    dict_expr, key_expr = tuple(refexpr.args...)
    @gensym dict key #defval
    quote
        ($dict)::Associative = ($dict_expr)
        ($key) = ($key_expr)
        if has(($dict), ($key))
            ($dict)[($key)]
        else
            ($dict)[($key)] = ($default) # returns the newly inserted value
#             ($defval) = ($default)
#             println("defval: ", ($defval))
#             ($dict)[($key)] = ($defval) # returns the newly inserted value
        end
    end
end

