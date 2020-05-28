#!/bin/bash
#$ -o medaka.log
#$ -j y
#$ -N medaka
#$ -pe smp 2-16
#$ -V -cwd
set -e

NSLOTS=${NSLOTS:=16}
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
if [[ -e ${dir}medaka/polished.fasta ]]; then
  echo "Assembly has already been polished. Exiting...."
  exit 0
fi

# load medaka 1.0.1
module purge
module load medaka/1.0.1

echo "Running Medaka via SCBS module..."
## commenting out temporarily, until SciComp adds new medaka singularity image to their repo.
#singularity exec --no-home -B ${dir}:/data /apps/standalone/singularity/medaka/medaka.0.8.1.staphb.simg \
#singularity exec --no-home -B ${dir}:/data /scicomp/home/pjx8/singularity-images/medaka.1.0.1.staphb.simg \
medaka_consensus -i ${dir}/reads.minlen500.600Mb.fastq.gz -m r941_min_high_g360 -t ${NSLOTS} -o ${dir}/medaka -d ${dir}racon/ctg.consensus.iteration4.fasta
