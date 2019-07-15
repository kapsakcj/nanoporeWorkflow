#!/bin/bash
#$ -o np_workflow.log
#$ -j y
#$ -N np_workflow
#$ -pe smp 1-36
#$ -V -cwd
#$ -l gpu=1
set -e

NSLOTS=${NSLOTS:=24}

OUTDIR=$1
FAST5DIR=$2
GENOMELENGTH=5000000 # TODO make this a parameter
LONGREADCOVERAGE=50  # How much coverage to target with long reads

set -u

thisDir=$(dirname $0);
thisScript=$(basename $0);
export PATH=$thisDir/../scripts:$PATH

if [ "$FAST5DIR" == "" ]; then
    echo "Usage: $thisScript outdir fast5dir/"
    exit 1;
fi;

# Setup any debugging information
date
hostname

# Setup tempdir
tmpdir=$(mktemp -p . -d ONT-ASM.XXXXXX)
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
mkdir $tmpdir/log
echo "$0: temp dir is $tmpdir";

uuid1=$(uuidgen)
jobName1="basecall-$uuid1"
qsub -pe smp 1-$NSLOTS -N $jobName1 -cwd -o log/$jobName1.log -j y \
  np_basecall-demux_guppy.sh $OUTDIR $FAST5DIR

# Now that it is demultiplexed, deal with each sample at a time.
for barcodeDir in $OUTDIR/barcode[0-9]*; do
  barcodeuuid=$(uuidgen)

  # Prep the sample
  jobName2="prepSample-$barcodeuuid"
  qsub -hold_jid $jobName1 -pe smp 1-$NSLOTS -N $jobName2 -cwd -o log/$jobName2.log -j y \
    np_prepSample_readLengths.sh $barcodeDir
  
  # Assemble the sample
  jobName3="assemble-$barcodeuuid"
  qsub -hold_jid $jobName2 -pe smp 1-$NSLOTS -N $jobName3 -cwd -o log/$jobName3.log -j y \
    np_assemble_wtdbg2.sh $barcodeDir

  # Polish the sample
  jobName4="polish-$barcodeuuid"
  qsub -hold_jid $jobName3 -pe smp 1-$NSLOTS -N $jobName4 -cwd -o log/$jobName4.log -j y \
    np_polish_medaka.sh $barcodeDir $FAST5DIR

done
