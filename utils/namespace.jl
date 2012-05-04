

const doublecolon = @eval (:(x::Int)).head


# -- ScannedVars --------------------------------------------------------------

type ScannedVars
    vars::Vector{Symbol}           # variable names in order
    vartypes::Dict{Symbol,Symbol}  # if it's encountered, the type is here
    locals::Set{Symbol}            # 

    ScannedVars() = new(Symbol[], Dict{Symbol,Symbol}(), Set{Symbol}())
end

function addsym(c::ScannedVars, name::Symbol, typename::Symbol, inlocal::Bool)
    println("addsym(inlocal=$inlocal): (name, typename) = ($name, $typename)")

    setvar = inlocal
    if !has(c.vartypes, name)
        push(c.vars, name)  # list the nane if first time encountered
        setvar = true
    end
    if setvar;  c.vartypes[name] = typename;  end
    if inlocal
        if has(c.locals, name)
            error("scanvars: syntax error: local $name declared twice")
        end
        add(c.locals, name)                
    end
end


# -- scanvars -----------------------------------------------------------------

scanlet(expr::Expr) = (@assert expr.head == :let; scanvars(ex.args[1]))

function scanvars(ex)
    c = ScannedVars()    
    scanvars(c, ex)
    { (name, c.vartypes[name]) | name in c.vars }
end

scanvars(c::ScannedVars, ex) = scanvars(c, ex, false)

scanvars(::ScannedVars, ::Any, ::Bool) = nothing
function scanvars(c::ScannedVars, ex::Expr, inlocal::Bool)
    println("scanvars(inlocal=$inlocal): ex=$ex")

    # don't recurse into scope forming exprs
    if contains([:for, :while, :try, :let, :type, :(->), :function], ex.head)
        return
    end
    if ex.head == :global; return; end

    # todo: handle type, abstract

    # still have to watch out for e g f(x)=x^2
    if ex.head == :(=)
        scanvars_lhs(c, ex.args[1], inlocal)
        scanvars(c, ex.args[2])
    elseif ex.head == :local
        foreach(arg->scanvars(c, arg, true), ex.args)
    elseif contains([:type, :abstract], ex.head)
        scanvars_typename(c, ex.args[1])
    else
        foreach(arg->scanvars(c, arg), ex.args)        
    end    
end

scanvars_lhs(c::ScannedVars, lhs::Symbol, il::Bool) = addsym(c, lhs, :Any, il)
function scanvars_lhs(c::ScannedVars, lhs::Expr, inlocal::Bool)
    println("scanvars_lhs(inlocal=$inlocal): lhs=$lhs")

    if lhs.head == :tuple
        foreach(arg->scanvars_lhs(c, arg, inlocal), lhs.args)
    elseif lhs.head == doublecolon
        addsym(c, lhs.args[1], lhs.args[2], inlocal)
    elseif contains([:ref, :call], lhs.head) 
        # indexed assignment/method declaration: do nothing
    else
        error("scanvars_lhs: unexpected lhs = ", lhs)
    end
end

scanvars_typename(c::ScannedVars, name::Symbol) = addsym(c, name, name)
function scanvars_typename(c::ScannedVars, ex::Expr)
    println("scanvars_typename: ex=$ex")

    if !((ex.head == comparison) && (length(ex.args) == 2))
        error("scanvars: invalid type signature ", ex)
    end
    scanvars_typename(ex.args[1])
end
