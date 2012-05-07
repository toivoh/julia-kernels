
load("utils/utils.jl")


pprintln(args...) = pprint(args..., '\n')
pprint(args...) = pprint(default_pretty(), args...)
pshow(args...)  = pshow(default_pretty(), args...)

# fallback for io::IO
pprint(io::IO, args...) = print(io, args...) 


# -- PrettyIO -----------------------------------------------------------------

abstract PrettyIO

function pprint(io::PrettyIO, s::String)
    n = strlen(s)
    if !chars_fit_on_line(io, n)
        pprint(io, '\n')
    end
    for c in s; pprint(io, c); end
end
pprint(io::PrettyIO, arg::Any) = pshow(io, arg)
pprint(io::PrettyIO, args...) = foreach(arg->pprint(io, arg), args)

pshow(io::PrettyIO, arg::Any) = pprint(io, sshow(arg))


#pprint(io::PrettyIO, t::Tuple) = pprint(indent(io), t...)
pprint(io::PrettyIO, v::Vector) = pprint(indent(io), v...)
pprint(io::PrettyIO, pprinter::Function) = pprinter(io)


comment(io::PrettyIO) = PrettyChild(io, ()->"# ")

indent(io::PrettyIO) = indent(io::PrettyIO, io.indent)
indent(io::PrettyIO, indent::Int) = (pre=" "^indent; PrettyChild(io, ()->pre))

subtree(io::PrettyIO, last::Bool) = subtree(io, last, io.indent)
function subtree(io::PrettyIO, last::Bool, indent::Int)
    nsp = indent >= 3 ? 1 : 0
    sp = " "^nsp
    subpretty(io, "+"*("-"^(indent-1-nsp))*sp,
                  last ? " "^indent : "|"*" "^(indent-1-nsp)*sp
              )
end
function subpretty(io::PrettyIO, firstprefix::String, restprefix::String)
    newline_hook = let firstline=true
        () -> (firstline ? (firstline=false; firstprefix) : restprefix)
    end
    PrettyChild(io, newline_hook)
end

# -- PrettyRoot ---------------------------------------------------------------

type PrettyRoot <: PrettyIO
    parent::IO
    width::Int
    indent::Int

    currpos::Int
    autowrap::Bool

    PrettyRoot(parent::IO, width::Int) = PrettyRoot(parent, width, 4)
    function PrettyRoot(parent::IO, width::Int, indent::Int)
        @expect width >= 1
        new(parent, width, indent, 0, false)
    end
end

function set_wrap_enable(io::PrettyRoot, wrap::Bool)
    io.autowrap = (wrap && ((io.currpos*2 <= io.width)) || io.autowrap)
end
function chars_fit_on_line(io::PrettyRoot, n::Integer)
    (!io.autowrap) || (io.currpos+n <= io.width)
end

function pprint(io::PrettyRoot, c::Char)
    if c=='\t'
        nsp::Int = (-io.currpos)&7
        if nsp==0; nsp=8; end
        print(io.parent, " "^nsp)
        io.currpos += nsp
    else
        print(io.parent, c)
        io.currpos += 1
    end
    if c == '\n'
        io.currpos = 0
        return true
    end
    if io.autowrap && (io.currpos >= io.width)
        return pprint(io, '\n')
    end
    return false
end


default_pretty() = PrettyRoot(OUTPUT_STREAM, 80)


# -- PrettyChild --------------------------------------------------------------

type PrettyChild <: PrettyIO
    parent::PrettyIO
    newline_hook::Function
    indent::Int

    function PrettyChild(parent::PrettyIO, newline_hook::Function)
        PrettyChild(parent, newline_hook, parent.indent)
    end
    function PrettyChild(parent::PrettyIO, newline_hook::Function, indent::Int)
        new(parent, newline_hook, indent)
    end
end

set_wrap_enable(io::PrettyChild, wrap::Bool) = set_wrap_enable(io.parent, wrap)
chars_fit_on_line(io::PrettyChild, n::Integer) = chars_fit_on_line(io.parent,n)

function pprint(io::PrettyChild, c::Char)
    newline = pprint(io.parent, c)::Bool
    set_wrap_enable(io.parent, false)
    if newline
        pprint(io.parent, io.newline_hook())
    end
    set_wrap_enable(io.parent, true)
    return newline
end


# == Expr prettyprinting ======================================================

const doublecolon = @eval (:(x::Int)).head

## single line list printing
function pshow_comma_list(io::PrettyIO, args::Vector, 
                          open::String, close::String) 
    pshow_delim_list(io, args, open, ", ", close)
end
function pshow_delim_list(io::PrettyIO, args::Vector, open::String, 
                          delim::String, close::String)
    pprint(io, {open, 
                io->pshow_list_delim(io, args, delim)},
           close)
end
function pshow_list_delim(io::PrettyIO, args::Vector, delim::String)
    for (arg, k) in enumerate(args)
        pshow(io, arg)
        if k < length(args)
            pprint(io, delim)
        end
    end
end

## show the body of a :block

#  Invoke on the line before the body.
#  Ends on the last line of the body.
pshow_mainbody(io::PrettyIO, ex) = pshow(io, ex)
function pshow_mainbody(io::PrettyIO, ex::Expr)
    if ex.head == :block
        args = ex.args
        for (arg, k) in enumerate(args)
            if !is_expr(arg, :line)
                pprint(io, "\n")
            end
            pshow(io, arg)
        end
    else
        pshow(io, ex)
    end
end

## show arguments of a block, and then body

#  Linebreaks like pshow_mainbody, but indents too
pshow_body(io::PrettyIO, body::Expr) = pshow_body(io, {}, body)
function pshow_body(io::PrettyIO, arg, body::Expr)
    pprint(io, {arg, io->pshow_mainbody(io, body) })
end
function pshow_body(io::PrettyIO, args::Vector, body::Expr)
    pprint(io, {
            io->pshow_comma_list(io, args, "", ""), 
            io->pshow_mainbody(io, body)
        })
end

## show an expr (prints no initial/final newline)
function pshow(io::PrettyIO, ex::Expr)
    const infix = {:(=)=>"=", :(.)=>".", doublecolon=>"::", :(:)=>":",
                   :(->)=>"->", :(=>)=>"=>",
                   :(&&)=>" && ", :(||)=>" || "}
    const parentypes = {:call=>("(",")"), :ref=>("[","]"), :curly=>("{","}")}

    head = ex.head
    args = ex.args
    nargs = length(args)

    if has(infix, head) && nargs==2             # infix operations
        pprint(io, "(",{args[1], infix[head], args[2]},")")
    elseif has(parentypes, head) && nargs >= 1  # :call/:ref/:curly
        pprint(io, args[1])
        pshow_comma_list(io, args[2:end], parentypes[head]...)
    elseif (head == :comparison) && (nargs>=3 && isodd(nargs)) # :comparison
        pprint("(",{args},")")
    elseif ((contains([:return, :abstract, :const] , head) && nargs==1) ||
            contains([:local, :global], head))
        pshow_comma_list(io, args, string(head)*" ", "")
    elseif head == :typealias && nargs==2
        pshow_delim_list(io, args, string(head)*" ", " ", "")
    elseif (head == :quote) && (nargs==1)       # :quote
        pshow_quoted_expr(io, args[1])
    elseif (head == :line) && (1 <= nargs <= 2) # :line
        let io=comment(io)
            if nargs == 1
                linecomment = "line "*string(args[1])*": "
            else
                @assert nargs==2
#               linecomment = "line "*string(args[1])*", "*string(args[2])*": "
                linecomment = string(args[2])*", line "*string(args[1])*": "
            end
            if chars_fit_on_line(io, strlen(linecomment)+13)
                pprint(io, "\t#  ", linecomment)
            else
                pprint(io, "\n", linecomment)
            end
        end
    elseif head == :if && nargs == 3  # if/else
        pprint(io, 
            "if ", io->pshow_body(io, args[1], args[2]),
            "\nelse ", io->pshow_body(io, args[3]),
            "\nend")
    elseif head == :try && nargs == 3 # try[/catch]
        pprint(io, "try ", io->pshow_body(io, args[1]))
        if !(is(args[2], false) && is_expr(args[3], :block, 0))
            pprint(io, "\ncatch ", io->pshow_body(io, args[2], args[3]))
        end
        pprint(io, "\nend")
    elseif head == :let               # :let 
        pprint(io, "let ", 
            io->pshow_body(io, args[2:end], args[1]), "\nend")
    elseif head == :block
        pprint(io, "begin ", io->pshow_body(io, ex), "\nend")
    elseif contains([:for, :while, :function, :if, :type], head) && nargs == 2
        pprint(io, string(head), " ", 
            io->pshow_body(io, args[1], args[2]), "\nend")
    else
        pprint(io, head)
        pshow_comma_list(indent(io), args, "(", ")")
    end
end


function pshow_quoted_expr(io::PrettyIO, sym::Symbol)
    if !is(sym,:(:)) && !is(sym,:(==))
        pprint(io, ":$sym")
    else
        pprint(io, ":($sym)")
    end
end
function pshow_quoted_expr(io::PrettyIO, ex::Expr)
    if ex.head == :block
        pprint(io, "quote ", io->pshow_body(io, ex), "\nend")
    else
        pprint(io, "quote(", {ex}, ")")
    end
end
