#!/bin/bash
#$ -o wtdbg2.log
#$ -e wtdbg2.err
#$ -j y
#$ -N wtdbg2
#$ -pe smp 2-16
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

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=1}
#echo '$NSLOTS set to:' $NSLOTS

INDIR=$1
#echo '$INDIR is set to:' $INDIR

GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=120  # How much coverage to target with long reads

set -u

if [ "$INDIR" == "" ]; then
    #echo ""
    echo "Usage: $0 barcode-fastq-dir/"
    echo ""
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d wtdbg2.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

dir=$INDIR

BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

# check to see if sample has already been assembled, skip if so
if [[ -e ${INDIR}/unpolished.fasta ]]; then
  echo "Reads have been assembled by 05_assemble script already. Skipping...."
  exit 0
fi

LENGTHS=$dir/readlengths.txt.gz
echo '$LENGTHS set to:' $LENGTHS

# Determine minimum read length for desired coverage.
# Do this by reading lengths from biggest to smallest,
# stopping when we get to the desired coverage and saving
# that read length.
MINLENGTH=$(zcat "$LENGTHS" | sort -rn | perl -lane 'chomp; $minlength=$_; $cum+=$minlength; $cov=$cum/'$GENOMELENGTH'; last if($cov > '$LONGREADCOVERAGE'); END{print $minlength;}')
echo "Min length for $LONGREADCOVERAGE coverage will be $MINLENGTH";

# Assemble.
echo "Assembling with wtdbg2..."
module purge
module load wtdbg2/2.4
wtdbg2 -t $NSLOTS -i ${dir}/all.fastq.gz -fo ${dir}/wtdbg2 -p 19 -AS 2 -s 0.05 -L $MINLENGTH -g $GENOMELENGTH -X $LONGREADCOVERAGE

# Generate the actual assembly using wtpoa-cns
echo "Generating consensus with wtpoa-cns...."
wtpoa-cns -t 16 -i $dir/wtdbg2.ctg.lay.gz -o $dir/unpolished.fasta 

