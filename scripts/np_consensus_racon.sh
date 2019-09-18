#!/bin/bash
#$ -o racon.log
#$ -e racon.err
#$ -j y
#$ -N racon
#$ -pe smp 2-24
#$ -V -cwd
set -e

#This function will check to make sure the directory doesn't already exist before trying to create it
make_directory() {
    if [ -e $1 ]; then
        echo "Directory "$1" already exists"
    else
        mkdir $1
        echo "Directory "$1" has been created"
    fi
}

NSLOTS=${NSLOTS:=24}
echo '$NSLOTS set to:' $NSLOTS

INDIR=$1

set -u

if [ "$INDIR" == "" ]; then
    echo "Usage: $0 barcode-dir/"
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d racon.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
echo "$0: temp dir is $tmpdir";

dir=$INDIR
echo '$dir is set to:' ${dir}
BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

FASTQ="${dir}reads.minlen1000.600Mb.fastq.gz"

# check to see if assembly has been through consensus correction, skip if so
# TODO - change the -e check here to check for output of racon
if [[ -e ${dir}polished.fasta ]]; then
  echo "Assembly has already been polished. Exiting...."
  exit 0
fi

module purge
module load minimap2/2.16
module load racon/1.3.1
make_directory ${dir}racon

# align long reads to draft assembly produced by flye/wtdbg2/etc
if [[ -e ${dir}minimap2/alignment.paf ]]; then
  echo "Reads have already been aligned to draft assembly. Skipping..."
else
  echo "Aligning reads to draft assembly with minimap2...."
  minimap2 -t ${NSLOTS} -x map-ont ${dir}*/assembly.fasta ${FASTQ} > ${dir}racon/alignment.paf
fi

# run Racon 4 times
if [[ -e ${dir}racon/ctg.consensus.iteration4.fasta ]]; then
  echo "Racon has already generated a consensus sequence. Skipping..."
else
  iteration=1
  # while loop to iterate through racon 4 times
  while [ $iteration -le 4 ]
  do  
    echo '$iteration =' $iteration
    echo "Running Racon to generate a consensus..."
    # if on first iteration, run racon using draft assembly from flye/wtdbg2
    if [[ $iteration == 1 ]]; then
      racon -m 8 -x -6 -g -8 -w 500 -t ${NSLOTS} ${FASTQ} ${dir}racon/alignment.paf ${dir}*/assembly.fasta > ${dir}racon/ctg.consensus.iteration${iteration}.fasta
    else 
      # if on 2/3/4 iteration, run racon on assembly corrected by prev iteration of racon
      prev_iteration=$((iteration-1))
      echo '$prev_iteration =' $prev_iteration
      # map reads back to consensus-corrected assembly      
      minimap2 -t ${NSLOTS} -x map-ont ${dir}racon/ctg.consensus.iteration${prev_iteration}.fasta ${FASTQ} > ${dir}racon/alignment.iteration${iteration}.paf
      # run racon again
      racon -m 8 -x -6 -g -8 -w 500 -t ${NSLOTS} ${FASTQ} ${dir}racon/alignment.iteration${iteration}.paf ${dir}racon/ctg.consensus.iteration${prev_iteration}.fasta  > ${dir}racon/ctg.consensus.iteration${iteration}.fasta
    fi
    # add 1 to iteration counter
    ((iteration++))
  done
fi
