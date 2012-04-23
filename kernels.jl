

function wrap_kernel_body(flat_code::Vector, indvars)
    body = expr(:block, flat_code)
    for k = 1:length(indvars)
        indvar = indvars[k]
        body = expr(:for, :(($indvar) = 1:shape[$k]), body)
    end
    body
end
