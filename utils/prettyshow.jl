
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
    if (n <= 20) && (chars_left_on_line(io) < n)
        pprint(io, '\n')
    end
    for c in s; pprint(io, c); end
end
# function pprint(io::PrettyIO, arg::Any)
#     m = memio()
#     print(m, arg)
#     pprint(io, takebuf_string(m))
# end
pprint(io::PrettyIO, arg::Any) = pshow(io, arg)
pprint(io::PrettyIO, args...) = foreach(arg->pprint(io, arg), args)

function pshow(io::PrettyIO, arg::Any)
    m = memio()
    show(m, arg)
    pprint(io, takebuf_string(m))
end


pprint(io::PrettyIO, t::Tuple) = pprint(subblock(io), t...)
pprint(io::PrettyIO, v::Vector) = pprint(subblock(io), v...)
pprint(io::PrettyIO, pprinter::Function) = pprinter(io)


comment(io::PrettyIO) = PrettyChild(io, ()->"# ")

subblock(io::PrettyIO) = subblock(io::PrettyIO, io.indent)
subblock(io::PrettyIO, indent::Int) = (pre=" "^indent; subpretty(io, pre, pre))

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

    PrettyRoot(parent::IO, width::Int) = PrettyRoot(parent, width, 4)
    function PrettyRoot(parent::IO, width::Int, indent::Int)
        @expect width >= 1
        new(parent, width, indent, 0)
    end
end

chars_left_on_line(io::PrettyRoot) = io.width-io.currpos

function pprint(io::PrettyRoot, c::Char)
    print(io.parent, c)
    io.currpos += 1
    if c == '\n'
        io.currpos = 0
        return true
    end
    if io.currpos >= io.width
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

chars_left_on_line(io::PrettyChild) = chars_left_on_line(io.parent)

function pprint(io::PrettyChild, c::Char)
    newline = pprint(io.parent, c)::Bool
    if newline
        pprint(io.parent, io.newline_hook())
    end
    return newline
end


# == Expr prettyprinting ======================================================

const doublecolon = @eval (:(x::Int)).head

function pshow_comma_list(io::PrettyIO, args::Vector, 
                          open::String, close::String) 
    pshow_delim_list(io, args, open, ", ", close)
end
function pshow_delim_list(io::PrettyIO, args::Vector, open::String, 
                          delim::String, close::String)
    pprint(io, 
           (open, 
                io->pshow_list_delim(io, args, delim)),
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


pshow_body(io::PrettyIO, ex) = pshow(io, ex)
function pshow_body(io::PrettyIO, ex::Expr)
    if ex.head == :block
        #pshow_list_delim(io, ex.args, "\n")
        args = ex.args
        for (arg, k) in enumerate(args)
            pshow(io, arg)
            if (k < length(args)) && !is_expr(args[k+1], :line)
                pprint(io, "\n")
            end
        end
    else
        pshow(io, ex)
    end
end

function pshow(io::PrettyIO, ex::Expr)
    head = ex.head
    args = ex.args
    nargs = length(args)

    const infix = {:(=)=>"=", :(.)=>".", doublecolon=>"::", 
                   :(&&)=>" && ", :(||)=>" || "}
    const parentypes = {:call=>("(",")"), :ref=>("[","]"), :curly=>("{","}")}

    if has(infix, head) && nargs==2             # infix operations
        pprint(io, "(",(args[1], infix[head], args[2]),")")
    elseif has(parentypes, head) && nargs >= 1  # :call/:ref/:curly
        pprint(io, args[1])
        pshow_comma_list(io, args[2:end], parentypes[head]...)
    elseif (head == :comparison) && nargs==3    # :comparison
        pprint("(",{args},")")
    elseif ((contains([:return, :abstract] , head) && nargs==1) ||
        (head == :typealias && nargs==2))       # :return/:abstract/:typealias
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
            if chars_left_on_line(io) >= strlen(linecomment)+13
                pprint(io, "\t#  ", linecomment)
            else
                pprint(io, "\n", linecomment)
            end
        end
    elseif head == :if && nargs == 3  # if/else
        pprint(io, 
            "if ", (ex.args[1], #"\n", 
                io->pshow_body(io, ex.args[2])
            ), "\nelse", {#"\n",
                io->pshow_body(io, ex.args[3])
            }, "\nend")
    elseif head == :try && nargs == 3 # try[/catch]
        pprint(io, 
            "try", (#"\n",
                io->pshow_body(io, ex.args[1]),
        ))
        if !(is(ex.args[2], false) && is_expr(ex.args[3], :block, 0))
            pprint(io, 
                "\ncatch ", ex.args[2], {#"\n",
                    io->pshow_body(io, ex.args[1])
            })
        end
        pprint(io, "\nend")
    elseif head == :let               # :let 
        pprint(io, "let ", 
            io->pshow_headbody(io, args[2:end], args[1]), "\nend")
    elseif head == :block
        pprint(io, "begin ", io->pshow_headbody(io, [], ex), "\nend")
    elseif contains([:for, :function, :if, :type], head) && nargs == 2
        pprint(io, string(head), " ", 
            io->pshow_headbody(io, args[1:1], args[2]), "\nend")
    else
        pprint(io, head)
        pshow_comma_list(subblock(io), args, "(", ")")
    end
end

function pshow_headbody(io::PrettyIO, args::Vector, body::Expr)
    pprint(io, (
            io->pshow_comma_list(io, args, "", ""), #"\n",
            io->pshow_body(io, body)
        ))
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
        #pshow_delim_list(io, ex.args, "quote\n", "\n", "\nend")
        pprint(io, 
            "quote ", {#"\n",
                io->pshow_body(io, ex)
            }, "\nend")        
    else
        pprint(io, "quote(", {ex}, ")")
    end
end
