julia-kernels v0.1
==================
Toivo Henningsson

This is a small suite of tools aimed at being able to write kernels in Julia, 
which could be executed on the CPU, or as GPU kernels. 
The current version has a simple Julia backend, 
speed seems to be somewhat slower than a handcoded kernel. 

Usage
-----

The currently supported syntax is

    @kernel let
        A = B.*C + D
        dest1[...] = A
        dest2[...] = A + C
    end

which would be roughly equivalent to

    let
        A = B.*C + D
        dest1[:,:] = A
        dest2[:,:] = A + C        
    end

if `A, B, C, D` are 2d `Arrays` of the same size. 
One difference is that the value of the `@kernel let` block is `nothing`.
(Plan: allow to specify a value/value tuple) as last expression)   

The idea is to implement a subset of Julia that can be easily converted into a kernel. 
(Though the syntax is slightly different so far, eg `dest[...]` 
instead of `dest[:,:]`)

Internals
=========
julia-kernels currently consists of the following parts:   

**DAG:** directed acyclic graph representation of computations, along with graph manipulation. The DAG format is the common language of the other parts.   
**Front end:**  Turns julia abstract syntax trees (AST) into DAG:s.   
**Midsection:** Transforms DAG:s into new ones.   
**Back end:**   Turns a DAG into a runnable kernel function.   
**Main:**       Connects the parts to together and defines the `@kernel` macro.

The dependence structure is simple: everything depends on **DAG**,
and only **Main**, which ties it all together, depends on anything else.

DAG
---

    Files: dag/dag.jl         The Node and Expression types
           dag/transforms.jl  Tools for transforming DAGs
           dag/pshow_dag.jl   Pretty-printing of DAGs. 
                              Relies on prettyshow/prettyshow.jl

`dag/dag.jl:` DAG nodes are represented by the type `Node{T<:Expression}`.
A DAG can represent linear julia code faithfully, but it can also represent other things.

Each node has arguments `args::Vector{Node}`, 
and a value `val::T` that contains data particular to the node's type.
Node types are distinguished by the type `T<:Expression` of `val`.
The `Expression` hierarchy, and corrsponding `Node` hierarchy,
makes it convenient to manipulate DAGs using dispatch on node type.   
A DAG is represented by its _sink_ node, which depends indirectly on all other nodes in the DAG. The code uses a `TupleNode` as a supersink to gather multiple sinks.

`dag/transforms.jl` contains tools to transform DAGs into new DAGs (or other things). The convention is that a DAG is immutable once it is created; all transformations create new DAGs.

`dag/pshow_dag.jl` implements pretty-printing of DAG:s by
`pshow(sink)/pprint(sink)`. The underlying `prettyshow/prettyshow.jl´ can also
be used to pretty print julia ASTs.

Front end
---------
`tangle.jl` transforms julia ASTs into DAGs.

Midsection
----------
`midsection.jl` implements transformations input DAG -> kernel DAG.

Back end
--------
`julia_backend.jl` implements `untangle(sink::Node)` to create a 
julia AST from a DAG. 
It also contains `wrap_kernel_body()` to add the necessary for loops around
the produced julia code.

Main
----
`kernels.jl` implements the `@kernel` macro.
It ties the parts together to form the processing chain

    AST --> raw DAG --> general DAG --> argument type specific DAG --> kernel
    Front end | Front midsection |  Back midsection  |         Back end
           Front half            |               Back half

Utils
-----
`utils/` contains various utils used by different files.
I want to thank Jeff Bezanson for creating the `@staged` macro,
(in `utils/staged.jl`) which I'm using for the backend. Great work!
