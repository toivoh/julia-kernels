
load("utils/utils.jl")


type PrettyIO
    width::Int
    linebegin_hook::Function
    io
    currpos::Int
    indent::Int

    function PrettyIO(width::Int, linebegin_hook::Function, io, currpos::Int)
        @expect width >= 1
        new(width, linebegin_hook, io, currpos, 3)
    end
    function PrettyIO(width::Int, linebegin_hook::Function, io)
        PrettyIO(width, linebegin_hook, io, 0)
    end
    function PrettyIO(width::Int, linebegin_hook::Function)
        global OUTPUT_STREAM
        PrettyIO(width, linebegin_hook, OUTPUT_STREAM)
    end
    PrettyIO(width::Int) = PrettyIO(width, ()->"")
end

default_pretty() = PrettyIO(80)


subtree(io::PrettyIO, last::Bool) = subtree(io, last, io.indent)
function subtree(io::PrettyIO, last::Bool, indent::Int)
    nsp = indent >= 3 ? 1 : 0
    sp = " "^nsp
    subpretty(io, "+"*("-"^(indent-1-nsp))*sp,
                  last ? " "^indent : "|"*" "^(indent-1-nsp)*sp
              )
end

function subpretty(io::PrettyIO, firstprefix::String, restprefix::String)
    pprint(io, firstprefix)
    linebegin = let firstline=true
        () -> (firstline ? (firstline=false; "") : restprefix)
    end
    subio = PrettyIO(io.width-strlen(restprefix), linebegin, io)
end



pprint(io::IO, args...) = print(io, args...)

function pprint(io::PrettyIO, c::Char)
    if io.currpos == 0
        pprint(io.io, io.linebegin_hook())
    end
    pprint(io.io, c)
    io.currpos += 1
    if c == '\n';  io.currpos = 0;  end
    if io.currpos >= io.width;  pprint(io, '\n');  end    
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



