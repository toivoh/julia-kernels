
#load("flatten.jl")

load("tangle.jl")
load("transforms.jl")

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

function flatten_kernel_tangle(code::Expr)
    value, dag, context = tangle(code)
    bottom2 = scattered(dag.bottom)
    bottom3 = count_uses(bottom2)
    dag3 = DAG(bottom3)
    order!(dag3)
    flat_code = untangle(dag3)

    arguments = append(get(dag3.symnode_names, :output, Symbol{}),
                       get(dag3.symnode_names, :input,  Symbol{}))
                       
    flat_code, arguments
end

function make_kernel(code, nd)
    flat_code, arguments = flatten_kernel_tangle(code)
    println("arguments = ", arguments)

    #indvars = gensym(32) # just some number of dims that should be enough
    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

    staged = true

    fdef = wrap_kernel(arguments, flat_code, indvars[1:nd], staged)
    fdef, arguments
end

macro kernel(nd, code)
    fdef, arguments = make_kernel(code, nd)
    kernel = eval(fdef)
    expr(:call, kernel, arguments...)    
end
