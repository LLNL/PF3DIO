#!/bin/ksh
#
# batch submissions should be made from the directory containing mpio2.i
#

umask 027

echo "Starting pf3d-io run"
typeset -x CODE_DIR=/usr/gapps/yorick/arch/$SYS_TYPE/new/

# To run as a batch job, try submitting like this:
#   sbatch  -N 2 -n 72 --exclusive -p pbatch --time 30:00 run-toss3.ksh

date

srun -i0 -c1 -n $SLURM_NPROCS $CODE_DIR/bin/mpy <<- MPY_CMDS
    mp_include,"mpio2.i";
    basedir= "/p/lustre1/${LOGNAME}/pf3d-io/";
    mpio;
    quit;
MPY_CMDS

date

exit
