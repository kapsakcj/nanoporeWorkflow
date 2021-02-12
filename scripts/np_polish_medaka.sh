#!/bin/bash
#$ -o medaka.log
#$ -j y
#$ -N medaka
#$ -pe smp 2-8
#$ -V -cwd
set -e

NSLOTS=${NSLOTS:=8}
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
tmpdir=$(mktemp -p . -d medaka.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
echo "$0: temp dir is $tmpdir";

dir=$INDIR
echo '$dir is set to:' ${dir}
BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

# commented out because unused variable
#FASTQ="$dir/all.fastq.gz"

# check to see if assembly has been polished, skip if so
if [[ -e ${dir}medaka/consensus.fasta ]]; then
  echo "Racon-polished assembly has already been polished with Medaka. Exiting...."
  exit 0
fi

# load singularity since singularity 3.5.3 is in your path by default (as of 17 June 2020)
source /etc/profile.d/modules.sh
module purge
module load singularity/3.5.3

# print medaka version; run medaka 
singularity exec --no-home -B $PWD:/data /apps/standalone/singularity/medaka/medaka.1.2.0.staphb.sif medaka --version

echo "Running Medaka via Singularity container..."
singularity exec --no-home -B ${dir}:/data /apps/standalone/singularity/medaka/medaka.1.2.0.staphb.sif \
medaka_consensus -i /data/reads.minlen500.600Mb.fastq.gz -m r941_min_high_g360 -t ${NSLOTS} -o /data/medaka -d /data/racon/ctg.consensus.iteration4.fasta

# copy final medaka-polished asm up one to main barcode directory, name it something obvious
# would be nice to later incorporate sample ID and run ID here later
cp -nv ${dir}medaka/consensus.fasta ${dir}final.asm.${BARCODE}.fasta
