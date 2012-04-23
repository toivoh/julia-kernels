
load("flatten.jl")
load("staged.jl")

quote_expr(ex) = expr(:quote, ex)
quote_tuple(t) = expr(:tuple, {t...})

function wrap_kernel_body(flat_code::Vector, indvars)
    Xref = expr(:ref, :X, indvars...)
#    prologue = {:( readinput(X) = $Xref ),
#                :( writeoutput(X,y) = $Xref=y )}
    prologue = { :(indvars=$(quote_tuple(indvars))) }

    body = expr(:block, append(prologue, flat_code))
    for k = 1:length(indvars)
        indvar = indvars[k]
        body = expr(:for, :(($indvar) = 1:shape[$k]), body)
    end
    body
end

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

function make_kernel(nd, code)
    # flatten the code
    symbols = HashTable{Symbol,SymEntry}()
    flat_code = {}
    receive = ex->append!(flat_code, {ex})
    context = Context(symbols, receive)
    value = flatten(context, code)

    #indvars = gensym(32) # just some number of dims that should be enough
    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead
    
    staged = true
    fdef = wrap_kernel(context, flat_code, indvars[1:nd], staged)
    kernel = eval(fdef)

    arguments = append(context.outputs, context.inputs)

    expr(:call, kernel, arguments...)
end

macro kernel(nd, code)
    make_kernel(nd, code)
end
