
load("utils/req.jl")
req("utils/utils.jl")


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

function code_checkexpect_call(predexpr::Expr)
    @assert predexpr.head == :call
    pred, args = predexpr.args[1], predexpr.args[2:end]
    qpredexpr =  quoted_expr(predexpr)

    quote; let args = ($quoted_tuple(args))
        ($pred)(args...) ? nothing : fail_expect(($qpredexpr), ($pred), args)
    end; end
end
# tie into @expect
function code_checkexpect(ex::Expr)
    if is_expr(ex, :call); code_checkexpect_call(ex)
    else;                  default_code_checkexpect(ex);   end
end



@failexpect is_expr(ex, head::Symbol) = "expected expr(:$head,...), got $ex"
