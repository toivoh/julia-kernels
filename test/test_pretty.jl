
load("utils/prettyprint.jl")
load("dag.jl")


#pprint(PrettyIO(10, ()->" -=- "), "a\n0123456789fdbkjhgfknbgkjfs")

c=CallNode(SymNode(:+,:call), LiteralNode(1), LiteralNode(2))
d=CallNode(SymNode(:+,:call), c,c)

pprintln(d)
