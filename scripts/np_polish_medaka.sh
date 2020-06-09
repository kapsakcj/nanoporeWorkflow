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

# load singularity since it doesn't do it by default anymore
# TODO upgrade to new singularity 3.5 version when module is available
source /etc/profile.d/modules.sh
module purge
module load singularity/2.5-patch

# run medaka 
echo "Running Medaka via Singularity container..."
# singularity exec --no-home option not in singularity 2.5 TODO add back in
singularity exec -B ${dir}:/data /apps/standalone/singularity/medaka/medaka.1.0.1.staphb.simg \
medaka_consensus -i /data/reads.minlen500.600Mb.fastq.gz -m r941_min_high_g360 -t ${NSLOTS} -o /data/medaka -d /data/racon/ctg.consensus.iteration4.fasta
