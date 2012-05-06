
load("utils/utils.jl")


type PrettyIO
    width::Int
    newline_callback::Function
    io
    currpos::Int

    function PrettyIO(width::Int, newline_callback::Function, io)
        @expect width >= 1
        new(width, newline_callback, io, 0)
    end
    PrettyIO(width::Int) = PrettyIO(width, ()->nothing)
    function PrettyIO(width::Int, newline_callback::Function)
        global OUTPUT_STREAM
        PrettyIO(width, newline_callback, OUTPUT_STREAM)
    end
end

default_pretty() = PrettyIO(10)


pprint(io::IO, args...) = print(io, args...)

function pprint(io::PrettyIO, c::Char)
    pprint(io.io, c)
    io.currpos += 1
    if io.currpos >= io.width
        c = '\n'
        pprint(io.io, c)
    end    
    if c == '\n'
        io.currpos = 0
        io.newline_callback()
    end
end
function pprint(io::PrettyIO, s::String)
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


pprintln(args...) = pprint(args..., '\n')
pprint(args...) = pprint(default_pretty(), args...)

