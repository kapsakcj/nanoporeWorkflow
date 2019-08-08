#!/bin/bash
#$ -o prepSample.log
#$ -e prepSample.err
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
echo '$NSLOTS is set to:' $NSLOTS

FASTQDIR=$1
echo '$FASTQDIR is set to:' $FASTQDIR

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

# check to see if reads have been compresesd and renamed to all-barcodeXX.fastq.gz
if [[ -e ${dir}/all.fastq.gz ]]; then
  echo "Reads have been concatenated and renamed by 03_prepSample script already. Exiting...."
  exit 0
fi

# Put all the individual gzip fastqs into a subdir,
# Concatenate them, and then remove them.
# Keep the aggregate fastq file.
echo "concatenating .fastq.gz files in barcode sub-dir..."
mkdir -p ${dir}/fastqChunks
mv ${dir}/*.fastq.gz ${dir}/fastqChunks
cat ${dir}/fastqChunks/*.fastq.gz > ${dir}/all.fastq.gz
rm -rf $dir/fastqChunks

# Combine reads and count lengths in one stream
echo "combining reads and counting read lengths..."
LENGTHS=${dir}/readlengths.txt.gz
zcat ${dir}/all.fastq.gz | perl -lne '
  next if($. % 4 != 2);
  print length($_);
' | sort -rn | gzip -cf > ${LENGTHS};
echo "Finished combining reads and counting read lengths."

