
load("utils/utils.jl")

typealias CharBuf Vector{Char}
charbuf() = Array(Char, 0)

type PrettyIO <: IO
    currline::CharBuf
    lines::Vector{String}
    width::Int
    
    PrettyIO(width) = (@expect width >= 1; new(charbuf(), String[], width))
end

function pretty_write(io::PrettyIO, c::Char)
    push(io.currline,c)
    if length(io.currline) >= io.width
        c = '\n'
        push(io.currline,c)
    end    
    if c == '\n'
        push(io.lines,string(io.currline...))
        io.currline = charbuf()
    end
#    show(c)
end
flush(::PrettyIO) = nothing


# == Uglyness =================================================================

function unimplemented_error(fname::String, args...)
    println("args=$args")
    error("Unimplemented: $fname", tuple({typeof(arg) for arg in args}...))
end

# duplicates
print(io::PrettyIO, xs...) = for x in xs; print(io, x); end
print(io::PrettyIO, s::ASCIIString) = print(io, s.data)

print(io::PrettyIO, c::Char) = (write(io,c); nothing)

# guards

function pretty_write(s::PrettyIO, arg) 
    if isa(arg, Char)
        pretty_write(s, arg)
    elseif isa(arg, Uint8)
        pretty_write(s, char(arg))
    else
        unimplemented_error("write", s, arg)
    end
end
write(s::PrettyIO, arg) = pretty_write(s, arg)
function write(s::PrettyIO, args...) 
    if length(args) == 1
        pretty_write(s, args[1])
    else
        unimplemented_error("write", s, args...)
    end
end
function print(s::PrettyIO, arg::Any)
    if isa(arg, Array{Uint8,1})
        for c in arg
            write(s, c)
        end
    else
        #unimplemented_error("print", s, arg)
        m = memio()
        print(m, arg)
        str = takebuf_string(m)
        str = convert(ASCIIString, str)
#         print("str = ", str)
        print(s, str)
    end
end
function show (s::PrettyIO, args...) 
    unimplemented_error("show", s, args...)
end
