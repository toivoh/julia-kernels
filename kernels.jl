
# kernels.jl
# ==========
# The @kernel macro and associated machinery
#

load("utils/staged.jl")
load("utils/utils.jl")
load("tangle.jl")
load("transforms.jl")
load("julia_backend.jl")


function collect_arguments(sink::Node)
    symnode_names = collect_symnode_names(sink)
    append(get(symnode_names, :output, Symbol{}),
           get(symnode_names, :input,  Symbol{}))
end

# transform raw DAG independent of argument types
function general_transform(rawdag::Node)
    dag2 = scattered(rawdag)
    dag3 = count_uses(dag2)
end

function gendag_to_specbody(gendag::Node, argnames::Vector{Symbol},
                            argtypes::Vector{Type})
    value, flat_code = untangle(gendag)

    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

    nd = ndims(argtypes[1])
    body = wrap_kernel_body(flat_code, indvars[1:nd])
    body = :(shape = size($(argnames[1])); $body)    
end


macro kernel(code)
    code_kernel(code)
end
function code_kernel(code)
    # Front end: ast --> dag
    #   todo: check format here. e g let/function/?
    @expect is_expr(code, :let)
    @expect length(code.args) == 1 # no let arguments, just body
#     value, rawdag, context = tangle(code.args[1])
    rawdag = tangle(code.args[1])[2]

    # Front midsection: dag transforms independent of argument types
    kernelargs = collect_arguments(rawdag)
    gendag = general_transform(rawdag)

    # Front end: 
    #   create staged kernel function
    @gensym kernel
    @eval begin
        @staged function ($kernel)($kernelargs...)
            # Back half: 
            #   Back midsection: argument type dependent transforms
            #   Back end: kernel instantiation
            gendag_to_specbody(($gendag), 
                               Symbol[{$quoted_exprs(kernelargs)...}...],
                               Type[{$kernelargs...}...])
        end
    end

    #    and insert a call to it in the code
    quote
        ($kernel)($kernelargs...)
    end
end
