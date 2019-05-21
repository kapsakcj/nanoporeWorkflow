#!/bin/bash
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

NSLOTS=${NSLOTS:=36}

OUTDIR=$1
FAST5DIR=$2
GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=50  # How much coverage to target with long reads:wq


if [[ "$FAST5DIR" == "" ]]; then
    echo "Usage: $0 outdir fast5dir/"
    echo "  The outdir will represent each sample in a 'barcode__' subdirectory"
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

# Setup tempdir in /tmp
# Cory recommended this since it will be faster than NFS GWA storage, lower latency as well
tmpdir=$(mktemp -p /tmp/$USER/ -d guppy.gpu.XXXXXX)
# rm -rf $tmpdir removed so that it doesn't delete files - TODO add back later
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

#copy fast5s to $tmpdir
make_directory $tmpdir/fast5
fast5tmp=$tmpdir/fast5
echo '$fast5tmp dir is set to:' $fast5tmp

# check to see if basecalling/demultiplexing has been done and files exist in OUTDIR
# if not, copy files into fast5tmp and begin
if [[ -e  ${OUTDIR}demux/ ]]; then
    echo "Demuxed fastqs present in OUTDIR. Exiting script..."
    exit 0
  else
    cp -rv $FAST5DIR $fast5tmp
fi

# no module load for guppy, since it's installed natively on node 98
module load qcat/1.0.1

# Basecalling using GPU
# should return version 3.0.3
guppy_basecaller -v
# basecalling
# check to see if basecalling has been done by checking OUTDIR/demux/ for sequencing_summary.txt
if [[ -e $OUTDIR/demux/sequencing_summary.txt ]]; then
  echo "FAST5 files have already been basecalled. Skipping."
else
  if [[ "$3" == "hac"  ]]; then
  guppy_basecaller -i $fast5tmp -s $tmpdir/fastq --num_callers $NSLOTS --qscore_filtering 7 --enable_trimming yes --hp_correct yes -r -x auto -m /opt/ont/guppy/data/template_r9.4.1_450bps_hac.jsn --chunk_size 1000 --gpu_runners_per_device 7 --chunks_per_runner 1100 --chunks_per_caller 10000 --overlap 50 --qscore_offset 0.25 --qscore_scale 0.91 --builtin_scripts 1 --disable_pings
  elif [[ "$3" == "fast" ]]; then
  guppy_basecaller -i $fast5tmp -s $tmpdir/fastq --kit SQK-LSK109 --flowcell FLO-MIN106 --num_callers $NSLOTS --qscore_filtering 7 --enable_trimming yes --hp_correct yes -r -x auto -m /opt/ont/guppy/data/template_r9.4.1_450bps_fast.jsn --chunk_size 10000 --gpu_runners_per_device 7 --chunks_per_runner 256 --overlap 50 --qscore_offset -0.4 --qscore_scale 0.98 --builtin_scripts 1 --disable_pings
  fi
fi

# should return qcat 1.0.1
qcat --version
# Demultiplex with qcat, multithreading not supported yet, already really fast on 1 thread
# Native barcoding kit barcodes 1-24 specified
# look in both pass and fail folders for reads (poor quality reads to be filterd out later w filtlong)
if [[ -e $OUTDIR/demux/none.fastq ]]; then
  echo "FASTQ files have already been demultiplexed. Skipping."
else
  echo "Demultiplexing with qcat now..."
  cat $tmpdir/fastq/*/*.fastq | qcat --trim -k NBD104/NBD114 -b $tmpdir/demux --detect-middle 
fi

# retain the sequencing summary
if [[ -e ${OUTDIR}demux/sequencing_summary.txt ]]; then
  echo "sequencing_summary.txt has already been hardlinked into OUTDIR/demux/"
else
  ln -v $tmpdir/fastq/sequencing_summary.txt $tmpdir/demux
fi

# copy demuxed fastqs into the specified OUTDIR
if [[ -e $OUTDIR/demux/none.fastq ]]; then
  echo "Demuxed fastqs have been transferred from tmpdir to OUTDIR. Skipping."
else
  cp -rv $tmpdir/demux $OUTDIR
fi

# create subdirectories for each barcode, move fastq file there (does not do so for none.fastq)
if [[ -e ${OUTDIR}demux/barcode06/ || -e ${OUTDIR}demux/barcode01/ ]]; then
  echo "fastqs assigned a barcode have already been moved into subdirs. Skipping"
else
  echo "Moving demuxed reads into subdirs...."
  for fastq in ${OUTDIR}demux/barcode*.fastq; do
    dir="${fastq%%.fastq}"
    mkdir -- "$dir"
    mv -- "$fastq" "$dir"
  done
fi

# making OUTDIR available to runner script for copying logfile into $tmpdir/log
export OUTDIR
