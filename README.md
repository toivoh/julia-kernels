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

Under the hood
--------------
The kernel body AST is processed by a tiny parser in `flatten.jl`,
which identifies inputs and outputs, transforms array-level operations into
kernel level ones, and produces a flat sequence of primitive operations
(which happen to be executable Julia code for the kernel body).
Example: `test_flatten.jl`

The Julia backend in `kernel.jl` wraps the raw kernel code into a Julia function with for loops, arguments etc.
It also includes the `@kernel` macro that creates a kernel
and substitutes a call to it using the actual runtime arguments.

I would like to thank Jeff Bezanson for creating the `@staged` macro, which I'm using for the backend. Great work!
