
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

function wrap_kernel(context::Context, flat_code::Vector, indvars)
    arguments = append(context.outputs, context.inputs)
    signature = expr(:call, :kernel, arguments...)

    body = wrap_kernel_body(flat_code, indvars)
    body = :(shape = size($(arguments[1])); $body)
    expr(:function, signature, body)
end
