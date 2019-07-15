#!/bin/bash
#$ -o medaka.log
#$ -j y
#$ -N medaka
#$ -pe smp 2-16
#$ -V -cwd
set -e

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=24}
#echo '$NSLOTS set to:' $NSLOTS

INDIR=$1

set -u

if [ "$INDIR" == "" ]; then
    echo "Usage: $0 projectDir"
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d nanopolish.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
echo "$0: temp dir is $tmpdir";

set +u
module try-load medaka/0.7.0
module load samtools/1.9
source /apps/x86_64/medaka/0.7.0/medaka/venv/bin/activate
set -u

dir=$INDIR
echo '$dir is set to:' ${dir}
BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

FASTQ="$dir/all.fastq.gz"

# check to see if assembly has been polished, skip if so
if [[ -e ${dir}/polished.fasta ]]; then
  echo "Assembly has already been polished. Exiting...."
  exit 0
fi

medaka_consensus -d "$dir/unpolished.fasta" -i "$FASTQ" -o "$dir/polished.medaka" -t $NSLOTS
ln -v "$dir/polished.medaka/consensus.fasta" $dir/polished.fasta

