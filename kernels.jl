
load("staged.jl")

function wrap_kernel_body(flat_code::Vector, indvars)
    Xref = expr(:ref, :X, indvars...)
    prologue = {:( readinput(X) = $Xref ),
                :( writeoutput(X,y) = $Xref=y )}

    body = expr(:block, append(prologue, flat_code))
    for k = 1:length(indvars)
        indvar = indvars[k]
        body = expr(:for, :(($indvar) = 1:shape[$k]), body)
    end
    body
end

quote_expr(ex) = expr(:quote, ex)

function wrap_kernel(context::Context, flat_code::Vector, indvars, 
                     staged::Bool)
    arguments = append(context.outputs, context.inputs)
    fname = gensym("kernel")
    signature = expr(:call, fname, arguments...)

    body = wrap_kernel_body(flat_code, indvars)
    body = :(shape = size($(arguments[1])); $body)
    
    if staged
        fdef = expr(:function, signature, quote_expr(body))
        fdef = :(@staged $fdef)
    else
        fdef = expr(:function, signature, body)
    end
    return :($fdef; $fname)
end
