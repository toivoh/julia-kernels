

const doublecolon = @eval (:(x::Int)).head


# -- ScannedConsts ------------------------------------------------------------

type ScannedConsts
    names::Vector{Symbol}  # const names in order
    declared::Set{Symbol}  # set of all declared (const) names

    ScannedConsts() = new(Symbol[], Set{Symbol}())
end

function addconst(c::ScannedConsts, name::Symbol)
    if !has(c.declared, name)
        add(c.declared, name)
        push(c.names, name)
    end
end


# -- scanconsts ---------------------------------------------------------------

function scanconsts_let(ex::Expr)
    @assert ex.head == :let
    c = ScannedConsts()
    scanconsts(c, ex.args[1]) # scan the body; header can't have consts
    c.names
end

# # todo: remove?
# function scanconsts(ex)
#     c = ScannedConsts()    
#     scanconsts(c, ex)
#     c.names
# end

scanconsts(::ScannedConsts, ::Any) = nothing
function scanconsts(c::ScannedConsts, ex::Expr)
#     println("scanconsts: ex=$ex")

    # don't recurse into scope forming exprs
    if contains([:for, :while, :try, :let, :(->)], ex.head)
        return
    end
    if ex.head == :global; return; end

    # still have to watch out for e g f(x)=x^2
    if ex.head == :(=)
        scanconsts_lhs(c, ex.args[1])
        scanconsts(c, ex.args[2])
    elseif contains([:type, :abstract, :typealias, :const], ex.head)
        scanconsts_const(c, ex.args[1])
    elseif ex.head == :function
        scanconsts_const(c, ex.args[1].args[1]) # assume ex.args[1] is a :call
    elseif ex.head == :return
        error("@namespace: return out of namespace scope not suppported")
    else
        foreach(arg->scanconsts(c, arg), ex.args)        
    end    
end

scanconsts_lhs(c::ScannedConsts, lhs::Symbol) = nothing
function scanconsts_lhs(c::ScannedConsts, ex::Expr)
#     println("scanconsts_lhs: ex=$ex")

    if ex.head == :call
        scanconsts_const(c, ex.args[1])
        foreach(arg->scanconsts(c, arg), ex.args[2:end])
    else
        foreach(arg->scanconsts(c, arg), ex.args)
    end
end

scanconsts_const(c::ScannedConsts, sym::Symbol) = addconst(c, sym)
function scanconsts_const(c::ScannedConsts, ex::Expr)
#    println("scanconsts_local: ex = $ex")
    if ex.head == :(=)
        scanconsts_const(c, ex.args[1])
        scanconsts(c, ex.args[2])
    elseif ex.head == :comparison
        scanconsts_const(c, ex.args[1])
        scanconsts(c, ex.args[3])
    elseif ex.head == :curly
        scanconsts_const(c, ex.args[1])
        foreach(arg->scanconsts(c, arg), ex.args[2:end])
    elseif ex.head == :global
    elseif ex.head == :local
        foreach(arg->scanconsts_const(c, arg), ex.args)        
    else
        error("scanconsts_const: unexpected ex = ", ex)
    end
end


# == @namespace ===============================================================

function declare_struct_type(structname, names, types)
    fields = {expr(doublecolon, name, t) for (name, t) in zip(names, types)}
    tdef = expr(:type, structname, expr(:block, fields))
    eval(tdef)
end

macro namespace(name::Symbol, body::Expr)
    namespace(name, body)
end

function namespace(typename::Symbol, body::Expr)
    if (body.head != :let)
        #error("@namespace: body must be a let block")
    end
    fieldnames = scanconsts_let(body)

    @gensym NamespaceStruct types x
    epilogue = quote
        
        $types = {typeof($x) for ($x) in {$fieldnames...}}
#        println($types)
        declare_struct_type(($expr(:quote, NamespaceStruct)),
                            {${expr(:quote, name) for name in fieldnames}...},
                            $types)
        ($NamespaceStruct)($fieldnames...)
    end        

    augblock = expr(:block, body.args[1], epilogue)    
    auglet   = expr(:let, augblock, body.args[2:end]...)

    quote
        $typename = $auglet
        nothing
    end
end
