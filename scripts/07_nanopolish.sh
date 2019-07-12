#!/bin/bash
#$ -o nanopolish.log
#$ -e nanopolish.err
#$ -j y
#$ -N nanopolish
#$ -pe smp 2-16
#$ -V -cwd
set -e

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=48}
echo '$NSLOTS set to:' $NSLOTS

INDIR=$1
echo '$INDIR set to:' $INDIR
FAST5DIR=$2
echo '$FAST5DIR set to:' $FAST5DIR

set -u

if [ "$FAST5DIR" == "" ]; then
    echo "Usage: $0 projectDir fast5Dir"
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d nanopolish.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
echo "$0: temp dir is $tmpdir";

module load nanopolish/0.11.1
module load minimap2/2.16
module load samtools/1.8
module load tabix/0.2.6
module load gcc/5.5
module load Python/3.7

dir=$INDIR
echo '$dir is set to:' ${dir}
BARCODE=$(basename ${dir})
echo '$BARCODE is set to:' $BARCODE

FASTQ="$dir/all.fastq.gz"

# check to see if assembly has been polished, skip if so
if [[ -e ${dir}/polished.fasta ]]; then
  echo "Assembly has already been polished by 07_nanopolish script. Exiting...."
  exit 0
fi

#nanopolish index -d $FAST5DIR $FASTQ
if [ ! -e "$dir/.nanopolish-index" ]; then
  echo "nanopolish indexing fast5 files..."
  nanopolish index -s ${dir}/../sequencing_summary.txt -d $FAST5DIR $FASTQ
  touch $dir/.nanopolish-index
else
  echo "fast5 files have already been indexed by nanopolish. Skipping..."
fi

# Map the reads to get a bam
if [ ! -e "$dir/.mapped-reads" ]; then
  echo "mapping reads to the unpolished assembly with minimap2..."
  minimap2 -a -x map-ont -t $NSLOTS ${dir}/unpolished.fasta ${dir}/all-${BARCODE}.fastq.gz | \
    samtools view -bS -T ${dir}/unpolished.fasta > ${dir}/unsorted.bam
  samtools sort -l 1 --threads $(($NSLOTS - 1)) ${dir}/unsorted.bam > ${dir}/reads.bam
  samtools index ${dir}/reads.bam
  rm ${dir}/unsorted.bam
  samtools faidx ${dir}/unpolished.fasta # unsure if this is needed
  touch ${dir}/.mapped-reads
else
  echo "reads have already been mapped to the unpolished assembly. Skipping..."
fi

# Start a loop based on suggested ranges using nanopolish_makerange.py
# but invoke it with python
RANGES=$(python $(which nanopolish_makerange.py) $dir/unpolished.fasta --overlap-length 1000 --segment-length 10000);
export numRanges=$(wc -l <<< "$RANGES")
echo "RANGES: $(tr '\n' ' ' <<< "$RANGES")"
echo "Calling variants on $numRanges ranges in the assembly. Progress bar will show one dot per range skipped due to previous results."
echo "0" > $dir/rangesCounter.txt
echo "$RANGES" | xargs -P $NSLOTS -n 1 bash -c '
  window="$0";
  dir="'$dir'";
  BARCODE="'$BARCODE'";

  # Progress counter
  lockfile -l 3 $dir/rangesCounter.txt.lock
  counter=`cat $dir/rangesCounter.txt`
  counter=$(($counter + 1))
  echo "$counter" > $dir/rangesCounter.txt
  rm -f $dir/rangesCounter.txt.lock

  # Do not redo results
  if [ -e "$dir/.$window-vcf" ]; then
    echo -ne ".";
    exit
  fi

  echo "Nanopolish variants on $window ($counter/$numRanges)"
  nanopolish variants --consensus -r $dir/all-${BARCODE}.fastq.gz -b $dir/reads.bam -g $dir/unpolished.fasta -t 1 --min-candidate-frequency 0.1 --min-candidate-depth 20 -w "$window" --max-haplotypes=1000 --ploidy 1 > $dir/consensus.$window.vcf 2>$dir/consensus.$window.log;

  # Record that we finished these results
  touch $dir/.$window-vcf
'
echo

# Run merge on vcf files
echo "nanopolish vcf2fasta"
nanopolish vcf2fasta -g $dir/unpolished.fasta ${dir}/consensus.*.vcf > $dir/polished.fasta
echo "nanopolish vcf2fasta finished"

# help with some level of compression in the folder
\ls $dir/consensus.*.vcf | xargs -P $NSLOTS -n 1 bgzip

