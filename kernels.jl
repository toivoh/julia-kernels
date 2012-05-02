
load("flatten.jl")
load("staged.jl")

quote_expr(ex) = expr(:quote, ex)
quote_tuple(t) = expr(:tuple, {t...})

function wrap_kernel_body(flat_code::Vector, indvars)
    Xref = expr(:ref, :X, indvars...)
    prologue = { :(indvars=$(quote_tuple(indvars))) }

    body = expr(:block, append(prologue, flat_code))
    for k = 1:length(indvars)
        indvar = indvars[k]
        body = expr(:for, :(($indvar) = 1:shape[$k]), body)
    end
    body
end

function wrap_kernel(arguments::Vector, flat_code::Vector, indvars, 
                     staged::Bool)
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

function flatten_kernel(code::Expr)
    symbols = Dict{Symbol,SymEntry}()
    flat_code = {}
    receive = ex->append!(flat_code, {ex})
    context = Context(symbols, receive)
    value = flatten(context, code)

    arguments = append(context.outputs, context.inputs)
    
    flat_code, arguments
end

function make_kernel(nd, code)
    # flatten the code
    flat_code, arguments = flatten_kernel(code)

    #indvars = gensym(32) # just some number of dims that should be enough
    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead
    
    staged = true
    fdef = wrap_kernel(arguments, flat_code, indvars[1:nd], staged)
    kernel = eval(fdef)

    expr(:call, kernel, arguments...)
end

macro kernel(nd, code)
    make_kernel(nd, code)
end
