julia-kernels v0.0
==================
Toivo Henningsson

This is a small suite of tools aimed at being able to write kernels in Julia, which could be executed on the CPU, or as GPU kernels. 
The current version has a Julia backend, speed seems to be on the same order of magnitude as hand coded for loops.

Usage
-----

The currently supported syntax is

    @kernel 2 begin
        A = B.*C + D
        dest1[] = A
        dest2[] = A + C
    end

which would be roughly equivalent to

    A = B.*C + D
    dest1[:,:] = A
    dest2[:,:] = A + C

if `A, B, C, D` are 2d `Arrays` of the same size. One difference is that the intermediate variable `A` is not exported from the `@kernel` block.
The first parameter to `@kernel` (`2` in this example)
specifies the number of dimensions -- it should go away soon!

The idea is to implement a subset of Julia which can be easily converted into a kernel. (Though the syntax is so far slightly different, eg `dest[]` instead of `dest[:,:]`)

Example: `test_kernels.jl`

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
