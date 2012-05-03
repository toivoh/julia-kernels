
macro show(ex)
    :(println(($string(ex)), " = ", $ex) )
end


quoted_expr(ex) = expr(:quote, ex)
quoted_tuple(t) = expr(:tuple, {t...})

is_expr(ex, head::Symbol) = (isa(ex, Expr) && (ex.head == head))


# == @expect ==================================================================

fail_expect(predexpr) = error("Expected: ", string(predexpr))

default_checkexpect_code(ex) = :($ex ? nothing : fail_expect($quoted_expr(ex)))
make_checkexpect_code(ex)    = default_checkexpect_code(ex)

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
    else
        # no explicit message
        return make_checkexpect_code(predexpr)
    end    
end


# == split_fdef ===============================================================

function split_fdef(fdef::Expr)
    @expect (fdef.head == :function) || (fdef.head == :(=))
    @expect length(fdef.args) == 2
    signature, body = tuple(fdef.args...)
    @expect is_expr(signature, :call)
    @expect length(signature.args) >= 1
    (signature, body)
end
split_fdef(f::Any) = error("split_fdef: expected function definition, got\n$f")


# == @failexpect ==============================================================

const failexp_handlers = Dict{Function,Function}()

# add failed expect message generator, e g
# @failexpect is_expr(ex, head) = "expected expr(:$head,...), got $ex"
macro failexpect(fdef)
    signature, body = split_fdef(fdef)
    f, args = signature.args[1], signature.args[2:end]

    quote; let 
        const handler = get_failexp_handler(($f), ($string(f)))
        handler($args...) = $body
    end; end
end
function get_failexp_handler(f::Function, fname::String)
    if !has(failexp_handlers, f)
        hname = gensym("failexpect_handler_for__"*fname)
        failexp_handlers[f] = @eval begin
            ($hname)(args...) = nothing
            ($hname)
        end        
    end
    failexp_handlers[f]
end

function fail_expect(predexpr, pred::Function, args::Tuple)
    if has(failexp_handlers, pred); msg = failexp_handlers[pred](args...) 
    else                            msg = nothing; end

    is(msg, nothing) ? fail_expect(predexpr) : error(msg)
end

function make_checkexpect_code_call(predexpr::Expr)
    @assert predexpr.head == :call
    pred, args = predexpr.args[1], predexpr.args[2:end]
    qpredexpr =  quoted_expr(predexpr)

    quote; let args = ($quoted_tuple(args))
        ($pred)(args...) ? nothing : fail_expect(($qpredexpr), ($pred), args)
    end; end
end
# tie into @expect
function make_checkexpect_code(ex::Expr)
    if is_expr(ex, :call); make_checkexpect_code_call(ex)
    else;                  default_checkexpect_code(ex);   end
end



@failexpect is_expr(ex, head::Symbol) = "expected expr(:$head,...), got $ex"


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

