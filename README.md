**PF3DIO**
=======

PF3DIO is an I/O benchmark that has I/O patterns similar to
those in pF3D. pF3D is a laser-plasma simulation code developed
at LLNL. The benchmark can be used to assess the performance
of parallel file systems on HPC clusters. PF3DIO relies on Yorick,
an open source interpreted language available at:
https://github.com/LLNL/yorick
Read the Yorick section if Yorick is not installed at your site.


Quick Start
-----------

The pF3IO repo contains run scripts for HPC systems at LLNL.
To get started, make a copy of a run script and modify
it to match your system. You can type something like this to run
on an LLNL Broadwell cluster:

```shell
# allocate nodes to run on
salloc -N 4 -n 144 --exclusive

# run the benchmark
./run-toss3.ksh
```

The next section briefly describes pF3D and its I/O package.
If you are just interested in building and running the benchmark, jump down
to the Running section.


Overview of pF3D
-----------

pF3D is used to simulate the interaction between a high intensity laser
and a plasma (ionized gas) in experiments performed at LLNL's National
Ignition Facility. pF3D simulations can consume large amounts of computer
time, so it is important that it is well optimized.

pF3D uses many complex arrays and a few real arrays. These arrays
normally have float precision. Versions of the testsThe pF3DK kernels run
on CPUs and GPUs.

PF3DIO includes rotth and couple_waves kernels. These
kernels are loosely based on functions in pF3D, but have been
simplified to more clearly exhibit some compiler issues that
have arisen during the development of pF3D.

The key points about these functions from a compiler point
of view is that they use C99 complex variables, compute
sines and cosines, and have float complex, float and double
variables. The loops are SIMDizable and have OpenMP simd directives
on CPUs. The challenges are for the compiler to recognize that a loop
containing multiple data types and calls to math libraries
is SIMDizable. For bonus points a compiler needs to figure
out the correct SIMD size to use when the CPU supports multiple
vector widths (hint- the goal is to make the sines and cosines
fast). OpenMP 4.5 target offload is used by the GPU versions.

PF3DIO also includes some 2D FFT kernels. These kernels
perform 2D FFTs over xy-planes. A 2D FFT is performed
for all xy-planes so the FFT kernel operates on 3D arrays.

pF3D normally runs with xy-planes decomposed into multiple
MPI domains. Performing a 2D FFT is done by "transposing"
uso that all processes have complete rows of the grid. 1D FFTs
are performed on each row using a single process FFT.
The FFTs use the FFTW API or a vendor specific API
that is similar to FFTW (e.g. Nvidia cuFFT). Another transpose
is used to assemble complete columns in each process. A second set
of 1D FFTs is performed, and a final transpose takes the data
back to the original checkerboard decomposition.

The 2D FFTs are implemented using a "toolkit" of functions
that handle data movement. The FFTs can be performed using FFTW
or a vendor optimized FFT library. There are versions that
run in a single process and versions that run on multiple
MPI processes. The use of the toolkit instead of a single
monolithic function makes it easier to check the performance
of the individual pieces.


Running PF3DIO
-----------

The benchmark runs in a few minutes. 

The run-toss3.ksh script that runs a code built with very low optmization
to generate reference values. Another script runs an optimized code
and compares the results to the reference values.

The script for "toss3" is intended for 36 core Intel Broadwell nodes.
The script for "blueos" is intended for 40 core IBM Power 9 nodes.

To run on your own cluster, modify a script to point to Yorick
on your system and change the batch command and MPI launcher
command if your system does not use SLURM.

License
-----------

PF3DIO is distributed under the terms of the BSD-3 license. All new contributions must be made under the BSD-3 license.

See LICENSE and NOTICE for details.

SPDX-License-Identifier: BSD-3-Clause

LLNL-CODE-815620
