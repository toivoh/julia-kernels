julia-kernels v0.0
==================
Toivo Henningsson

This is a small suite of tools aimed at being able to write kernels in Julia, which could be executed on the CPU, or as GPU kernels. 
The current version has a Julia backend, speed seems to be comparable to hand coded for loops.

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

if `A, B, C, D` are 2d Arrays of the same size. One difference is that the intermediate variable `A` is not exported from the `@kernel`.
The 2 after `@kernel` specifies the number of dimensions -- it should go away soon!

The idea is to implement a subset of Julia which can be easily converted into a kernel. (Though the syntax is slightly different currently, eg `dest[]`)

Run/read test_kernels.jl for an example.

Under the hood
--------------
The kernel body AST is processed by a tiny parser in `flatten.jl`,
which identifies inputs and outputs, transforms array-level operations into
kernel level, and produces a flat sequence of elementary operations.
See `test_flatten.jl` for an example.

The Julia backend in kernel.jl wraps the raw kernel code into a Julia function with for loops, arguments etc.
It also includes the `@kernel` macro that creates a kernel and substitutes a call to the kernel with the actual runtime arguments.   
I'm using Jeff's staged functions for this backend, thanks a lot for these!

