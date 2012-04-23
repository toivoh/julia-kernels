

function wrap_kernel_body(flat_code::Vector, indvars)
#     prologue = {:( readinput(X) = X[_i,_j] ),
#                 :( writeoutput(X,y) = X[_i,_j]=y )}
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
