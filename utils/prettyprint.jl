
load("utils/utils.jl")


pprintln(args...) = pprint(args..., '\n')
pprint(args...) = pprint(default_pretty(), args...)

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
function pprint(io::PrettyIO, arg::Any)
    m = memio()
    print(m, arg)
    str = takebuf_string(m)
#    str = convert(ASCIIString, str)
    pprint(io, str)
end
pprint(io::PrettyIO, args...) = foreach(arg->pprint(io, arg), args)


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

    PrettyRoot(parent::IO, width::Int) = PrettyRoot(parent, width, 3)
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

