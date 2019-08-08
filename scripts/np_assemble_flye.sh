#!/bin/bash
#$ -o flye.log
#$ -e flye.err
#$ -j y
#$ -N flye
#$ -pe smp 2-36
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

NSLOTS=${NSLOTS:=36}
echo '$NSLOTS set to:' $NSLOTS

INDIR=$1
echo '$INDIR is set to:' $INDIR

GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=120  # How much coverage to target with long reads

set -u

if [ "$INDIR" == "" ]; then
    echo "Usage: $0 barcode-fastq-dir/"
    echo ""
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d flye.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

dir=$INDIR

BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

# check to see if sample has already been assembled, skip if so
if [[ -e ${INDIR}/unpolished.fasta ]]; then
  echo "Reads have been assembled by np_assemble_flye script already. Skipping...."
  exit 0
fi

LENGTHS=${dir}readlengths.txt.gz
echo '$LENGTHS set to:' $LENGTHS

# Determine minimum read length for desired coverage.
# Do this by reading lengths from biggest to smallest,
# stopping when we get to the desired coverage and saving
# that read length.
MINLENGTH=$(zcat "$LENGTHS" | sort -rn | perl -lane 'chomp; $minlength=$_; $cum+=$minlength; $cov=$cum/'$GENOMELENGTH'; last if($cov > '$LONGREADCOVERAGE'); END{print $minlength;}')
echo "Min length for $LONGREADCOVERAGE coverage will be $MINLENGTH";

module load flye/2.4.1

# Assemble.
echo "Assembling with flye..."
singularity exec --no-home -B $PWD:/data ~/singularity-images/flye.2.5.dhub \
  flye --nano-raw /data/${dir}all.fastq.gz -o /data/${dir}flye --g 96k --meta -t $NSLOTS

