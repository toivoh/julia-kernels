
load("dag/pshow_dag.jl")


c=CallNode(SymNode(:+,:call), LiteralNode(1), LiteralNode(2))
d=CallNode(SymNode(:+,:call), c,c)

pprintln(d)
