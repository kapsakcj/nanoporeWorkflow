#!/bin/bash
# UGE options removed, since this must be performed manually on node 98
# May eventually be added, if GPUs (Tesla V100s) are available via UGE/qsub
set -e

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=32}

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

# Setup tempdir in /tmp
# Cory recommended this since it will be faster than NFS GWA storage, lower latency as well
tmpdir=$(mktemp -p /tmp/pjx8/ -d guppy.gpu.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir } ' EXIT
mkdir $tmpdir/log
echo "$0: temp dir is $tmpdir";

# no module load for guppy, since it's installed natively on node 98
module load qcat/1.0.1

# Basecalling using GPU
# should return version 3.0.3
guppy_basecaller -v
# basecalling
guppy_basecaller -i $FAST5DIR -s $tmpdir/fastq --gpu_runners_per_device 48 --num_callers $NSLOTS --flowcell FLO-MIN106 --kit SQK-LSK109 --qscore_filtering 7 --enable_trimming yes --hp_correct yes -r -x auto --chunks_per_runner 96

#### Commented out to try qcat instead
# Demultiplex.  -r for recursive fastq search.
###guppy_barcoder -t $NSLOTS -r -i $tmpdir/fastq -s $tmpdir/demux

# should return qcat 1.0.1
qcat --version
# Demultiplex with qcat, multithreading not supported yet, already really fast on 1 thread
# Native barcoding kit barcodes 1-24 specified
# look in both pass and fail folders for reads (poor quality reads to be filterd out later w filtlong)
cat $tmpdir/fastq/*/*.fastq | qcat --trim -k NBD104/NBD114 -b $tmpdir/demux --detect-middle 

# retain the sequencing summary
ln -v $tmpdir/fastq/sequencing_summary.txt $tmpdir/demux

#### Commented out because qcat doesn't produce separate directories per barcode
# Make a relative path symlink to the sequencing summary
# file for each barcode subdirectory
#for barcodeDir in $tmpdir/demux/barcode[0-12]* $tmpdir/demux/unclassified; do
#  ln -sv ../sequencing_summary.txt $barcodeDir/;
#done

cp -rv $tmpdir/demux $OUTDIR

# create subdirectories for each barcode, move fastq file there (does not do so for none.fastq)
for fastq in $OUTDIR/demux/barcode*.fastq; do
  mkdir $OUTDIR/demux/$(echo $fastq | cut -d '/' -f 3 | cut -d '.' -f 1)
  mv $fastq $(echo $fastq | cut -d '.' -f 1)
done

# making OUTDIR available to runner script for copying logfile into $tmpdir/log
export $OUTDIR
