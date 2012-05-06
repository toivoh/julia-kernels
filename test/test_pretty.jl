
load("utils/prettyprint.jl")


pretty = PrettyIO(10)

println(pretty, "0123456789fdbkjhgfknbgkjfs")
#println(OUTPUT_STREAM, "0123456789fdbkjhgfknbgkjfs")

foreach(print, pretty.lines)
