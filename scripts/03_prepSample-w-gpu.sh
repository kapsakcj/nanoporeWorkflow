#!/bin/bash
#$ -o wtdbg2.log
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

NSLOTS=${NSLOTS:=24}

FASTQDIR=$1
echo '$FASTQDIR is set to:' $FASTQDIR

GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=50  # How much coverage to target with long reads

set -u

if [ "$FASTQDIR" == "" ]; then
    echo ""
    echo "Usage: $0 barcode-fastq-dir"
    echo ""
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d prepfastq.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

dir=$FASTQDIR
echo '$dir is set to:' $dir

BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

### commented out since gzipping is done by previous script
# Gzip them all
#uncompressed=$(\ls $dir/*.fastq 2>/dev/null || true)
#if [ "$uncompressed" != "" ]; then
#  echo "$uncompressed" | xargs -P $NSLOTS gzip 
#fi

# Put all the individual gzip fastqs into a subdir,
# Concatenate them, and then remove them.
# Keep the aggregate fastq file.
echo "concatenating .fastq.gz files in barcode sub-dir..."
mkdir -p ${dir}/fastqChunks
mv ${dir}/*.fastq.gz ${dir}/fastqChunks
cat ${dir}/fastqChunks/*.fastq.gz > ${dir}/all-${BARCODE}.fastq.gz
rm -rf $dir/fastqChunks

# Combine reads and count lengths in one stream
echo "combining reads and counting read lengths..."
LENGTHS=${dir}/readlengths.txt.gz
zcat ${dir}/all-${BARCODE}.fastq.gz | perl -lne '
  next if($. % 4 != 2);
  print length($_);
' | sort -rn | gzip -cf > ${LENGTHS};

