#!/bin/bash
if find logfile-gpu-basecalling.txt;
then
    cat logfile-gpu-basecalling.txt >> logfile-gpu-basecalling_prev.txt
fi

OUTDIR=$1
FAST5DIR=$2

if [ "$FAST5DIR" == "" ]; then
    echo "Usage: $0 outdir fast5dir/"
    echo "  The outdir will represent each sample in a 'barcode__' subdirectory"
    exit 1;
fi;

command time -v /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/01_basecall-w-gpu.sh $OUTDIR $FAST5DIR |& tee logfile-gpu-basecalling.txt

mv logfile-gpu-basecalling.txt $OUTDIR/log
