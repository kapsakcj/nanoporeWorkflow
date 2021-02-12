#!/bin/bash
#$ -o wtdbg2.log
#$ -e wtdbg2.err
#$ -j y
#$ -N wtdbg2
#$ -pe smp 2-16
#$ -V
#$ -cwd
set -e

NSLOTS=${NSLOTS:=24}

OUTDIR=$1
FAST5DIR=$2
GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=50  # How much coverage to target with long reads

set -u

if [ "$FAST5DIR" == "" ]; then
    echo "Usage: $0 outdir fast5dir/"
    echo "  The outdir will represent each sample in a 'barcode__' subdirectory"
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d chiron-qcat.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
mkdir $tmpdir/log
echo "$0: temp dir is $tmpdir";

# Test whether chiron is in the path
#chiron --help >/dev/null 

echo "Separating multifast5 files to single for compatibility with Chiron"
multi_to_single_fast5 -i $FAST5DIR --threads $NSLOTS -s $tmpdir/FAST5.single

# Base calling
modeldir=$(find $HOME/.local/lib/*/site-packages -mindepth 2 -type d -name DNA_default | head -n 1)
echo "Model can be found at $modeldir"
chiron call -i $tmpdir/FAST5.single -o $tmpdir/chiron -m $modeldir -t $NSLOTS

# Demultiplex with qcat
find $tmpdir/chiron -type f -name '*.fast5' -exec cat {} | \
  qcat -b $tmpdir/demux

mv $tmpdir/demux $OUTDIR

