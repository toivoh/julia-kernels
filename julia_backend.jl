
#load("transforms.jl")

# -- toexpr -------------------------------------------------------------------

toexpr(ex::LiteralEx) = ex.value
toexpr(ex::SymbolEx)  = ex.name

toexpr(ex::CallEx,     args...) = expr(:call,  args...)
toexpr(ex::RefEx,      args...) = expr(:ref,   args...)
toexpr(ex::TupleEx,    args...) = expr(:tuple, args...)
toexpr(ex::EllipsisEx, args...) = expr(:(...), args...)

toexpr(ex::AssignEx,   args...) = expr(:(=), args[1:2]...)# remove dependencies


# -- UntangleContext ----------------------------------------------------------

type Untangle
    code::Vector
    Untangle() = new({})
end
typealias UntangleContext Context{Untangle}

emit(c::UntangleContext, ex) = (push(c.c.code, ex); nothing)


# -- untangle -----------------------------------------------------------------

function untangle(bottom::Node)
    c = UntangleContext()
    value = evaluate(c, bottom)
    value, c.c.code
end

untangle(c::UntangleContext, node::KnotNode) = evaluate(c, node.args)[end]
untangle(c::UntangleContext, n::Node) = toexpr(n.val, evaluate(c, n.args)...)

function evaluate(c::UntangleContext, node::AssignNode)
    emit(c, untangle(c, node))
    return (@cached evaluate(c, get_rhs(node)))
end
function evaluate(c::UntangleContext, node::Node)
    ex = untangle(c, node)
    if !is(node.name, nothing)
        emit(c, expr(:(=), node.name, ex))
        return node.name
    end
    return ex
end


# -- wrap_kernel_body ---------------------------------------------------------

function wrap_kernel_body(flat_code::Vector, indvars)
    prologue = { :(indvars=$(quoted_tuple(indvars))) }

    body = expr(:block, append(prologue, flat_code))
    for k = 1:length(indvars)
        indvar = indvars[k]
        body = expr(:for, :(($indvar) = 1:shape[$k]), body)
    end
    body
end


# -- printing -----------------------------------------------------------------

print_untangled(bottom::Node) = (print_list(untangle(bottom)[2]))
