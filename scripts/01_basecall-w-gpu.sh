#!/bin/bash

# Curtis Kapsak pjx8@cdc.gov

# This script runs guppy_basecaller via port 9999 on guppy_basecall_server that 
# should be continously running on node98. Either fast or high-accuracy mode
# can be used. Guppy will produce demultiplexed, trimmed, and compressed fastqs.

# UGE options removed, since this must be performed manually on node 98
# May eventually be added, if GPUs (Tesla V100s) are available via UGE/qsub

#This function will check to make sure the directory doesn't already exist before trying to create it
make_directory() {
    if [ -e $1 ]; then
        echo "Directory "$1" already exists"
    else
        mkdir $1
        echo "Directory "$1" has been created"
    fi
}

set -e

source /etc/profile.d/modules.sh
module purge

# node98 has 20 threads
NSLOTS=${NSLOTS:=20}
OUTDIR=$1
FAST5DIR=$2

# make output directory if it doesn't exist
make_directory $1

# make sure user specifies an input dir
if [[ "$FAST5DIR" == "" ]]; then
      echo ""
      echo "    Usage: $0 outdir/ fast5dir/ fast"
      echo "               OR"
      echo "    Usage: $0 outdir/ fast5dir/ hac"
      echo ""
      exit 1;
fi;

# check to make sure $MODE is set to either 'fast' or 'hac'
case $3 in
    fast)
      echo '$MODE set to: "fast"'
      ;;
    hac)
      echo '$MODE set to: "hac"'
      ;;
    *| "" )
      echo ""
      echo "    Usage: $0 outdir/ fast5dir/ fast"
      echo "               OR"
      echo "    Usage: $0 outdir/ fast5dir/ hac"
      echo ""
      echo "Please specify 'fast' or 'hac' as the third argument to specify which basecaller model & config to use"
      exit 1
      ;;
esac

set -u

# Setup any debugging information
date
hostname
echo '$USER is set to:' $USER

# Setup tmpdir in /scratch
# Cory recommended this since it will be faster than NFS GWA storage, lower latency as well
tmpdir=$(mktemp -p /scratch/$USER/ -d guppy.gpu.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

# copy fast5s to $tmpdir
make_directory $tmpdir/fast5
fast5tmp=$tmpdir/fast5
echo '$fast5tmp dir is set to:' $fast5tmp
# check to see if basecalling/demultiplexing has been done and files exist in OUTDIR
# if not, copy files into fast5tmp and begin
if [[ -e  ${OUTDIR}demux/ ]]; then
    echo "Demuxed fastqs present in OUTDIR. Exiting script..."
    exit 0
else
    echo "Copying reads from $FAST5DIR to $tmpdir"
    cp -r $FAST5DIR $fast5tmp
fi

#### Basecalling using GPU ####
# should return version 3.2.2
guppy_basecaller -v
# check to see if basecalling has been done by checking OUTDIR/demux/ for sequencing_summary.txt
if [[ -e $OUTDIR/demux/sequencing_summary.txt ]]; then
  echo "FAST5 files have already been basecalled. Skipping."
else
  if [[ "$3" == "hac"  ]]; then
  guppy_basecaller -i $fast5tmp \
                   -s $tmpdir/demux \
                   --hp_correct yes \
                   -r \
                   -c dna_r9.4.1_450bps_hac.cfg \
                   --gpu_runners_per_device 2 \
                   --chunks_per_runner 1000 \
                   --num_callers 8 \
                   --compress_fastq \
                   --trim_barcodes \
                   --barcode_kits "EXP-NBD103" \
                   --num_barcode_threads 8 \
                   --port 9999
  elif [[ "$3" == "fast" ]]; then
  guppy_basecaller -i $fast5tmp \
                   -s $tmpdir/demux \
                   --hp_correct yes \
                   -r \
                   -c dna_r9.4.1_450bps_fast.cfg \
                   --gpu_runners_per_device 8 \
                   --chunks_per_runner 256 \
                   --num_callers 8 \
                   --compress_fastq \
                   --trim_barcodes \
                   --barcode_kits "EXP-NBD103" \
                   --num_barcode_threads 8 \
                   --port 9999 
  fi
fi

# copy demuxed fastqs into the specified OUTDIR
if [[ -e $OUTDIR/demux/none.fastq ]]; then
  echo "Demuxed fastqs have been transferred from tmpdir to OUTDIR. Skipping."
else
  echo "Copying reads from $tmpdir to $OUTDIR"
  cp -r $tmpdir/demux $OUTDIR
fi

# making OUTDIR available to runner script for copying logfile into $tmpdir/log
export OUTDIR
