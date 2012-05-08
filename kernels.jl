
# kernels.jl
# ==========
# The @kernel macro and associated machinery
#

load("utils/req.jl")
req("utils/staged.jl")
req("utils/utils.jl")
req("dag/transforms.jl")
req("tangle.jl")
req("midsection.jl")
req("julia_backend.jl")


# -- Front half: code -> general DAG (no argument types available yet) --------

function ast_to_gendag(code)
    # Front end: ast --> dag
    @expect is_expr(code, :let)
    @expect length(code.args) == 1 # no let arguments, just body
    rawdag = tangle(code.args[1])

    # Front midsection: DAG transforms independent of argument types
    kernelargs = collect_arguments(rawdag)
    gendag = general_transform(rawdag)
    
    (kernelargs, gendag)
end

function collect_arguments(sink::Node)
    symnode_names = collect_symnode_names(sink)
    append(get(symnode_names, :output, Symbol{}),
           get(symnode_names, :input,  Symbol{}))
end

# Transform raw DAG independent of argument types
function general_transform(rawdag::Node)
    dag2 = scattered(rawdag)
end


# -- Back half: (general DAG, argtypes) -> specific kernel body ---------------

function gendag_to_specbody(gendag::Node, argnames::Vector{Symbol},
                            argtypes::Vector{Type})

    # todo: Add middle processing dependent on argtypes

    # Back end: Create julia code and wrap into for loops
    value, flat_code = untangle(gendag)

    indvars = (:_i, :_j, :_k, :_l) # todo: use gensyms instead

    nd = ndims(argtypes[1])
    body = wrap_kernel_body(flat_code, indvars[1:nd])
    body = :(shape = size($(argnames[1])); $body)    
end


# -- @kernel ------------------------------------------------------------------

macro kernel(code)
    code_kernel(code)
end
function code_kernel(code)
    # Front end: 
    #   process code as far as we can without argument types
    kernelargs, gendag = ast_to_gendag(code)

    #   create staged kernel function to invoke back half
    @gensym kernel
    @eval begin
        @staged function ($kernel)($kernelargs...)
            # Back half
            gendag_to_specbody(($gendag), 
                               Symbol[{$quoted_exprs(kernelargs)...}...],
                               Type[{$kernelargs...}...])
        end
    end

    #    finally insert a call to it in the code
    quote
        ($kernel)($kernelargs...)
    end
end
