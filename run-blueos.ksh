#!/bin/ksh
#BSUB -nnodes 8
#BSUB -W 30          # hours:minutes
#BSUB -G lbpm        # bank to use
#BSUB -q pbatch      # queue to use
#BSUB -J pf3d-io
#BSUB -o pf3d-io_%J.out
#BSUB -e pf3d-io_%J.err
#BSUB -N
#
# bsub should be run from the directory containing mpio2.i
# The default values in BSUB comments can be overridden on the command line.
#

umask 027

##############################################################################
# Run the program

echo "Starting pf3d-io run"
typeset -x CODE_DIR=/usr/gapps/yorick/arch/$SYS_TYPE/new/

# To run as a batch job, try a command like this:
#   bsub  -nnodes 4 -W 30 run-blueos.ksh

date

lrun -N 4 -n 160 $CODE_DIR/bin/mpy <<- MPY_CMDS
    mp_include,"mpio2.i";
    basedir= "/p/gpfs1/${LOGNAME}/pf3d-io/";
    mpio;
    quit;
MPY_CMDS

date
