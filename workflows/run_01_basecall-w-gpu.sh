#!/bin/bash
# Curtis Kapsak, created May 2019

#This function will check to make sure the directory doesn't already exist before trying to create it
make_directory() {
    if [ -e $1 ]; then
        echo "Directory "$1" already exists"
    else
        mkdir $1
        echo "Directory "$1" has been created"
    fi
}

OUTDIR=$1
FAST5DIR=$2
MODE=$3

if find ${OUTDIR}log/logfile-gpu-basecalling.txt;
then
    cat ${OUTDIR}log/logfile-gpu-basecalling.txt >> ${OUTDIR}log/logfile-gpu-basecalling_prev.txt
    echo "--------------------------------" >> ${OUTDIR}log/logfile-gpu-basecalling_prev.txt
    echo "--------------------------------" >> ${OUTDIR}log/logfile-gpu-basecalling_prev.txt
fi

echo '$OUTDIR is set to:' ${OUTDIR}
echo '$FAST5DIR is set to :' ${FAST5DIR}
echo '$MODE is set to :' ${MODE}

if [ "$FAST5DIR" == "" ]; then
    echo "Specified dirs MUST end with a '/'"
    echo "Usage: $0 outdir/ fast5dir/"
    echo "  The outdir will represent each sample in a 'barcode__' subdirectory"
    exit 1;
fi;

make_directory ${OUTDIR}log

command time -v /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/01_basecall-w-gpu.sh ${OUTDIR} ${FAST5DIR} ${MODE} |& tee ${OUTDIR}log/logfile-gpu-basecalling.txt
