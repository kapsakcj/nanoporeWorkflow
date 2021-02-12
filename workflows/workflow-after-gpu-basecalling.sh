#!/bin/bash
#$ -o workflow-after-gpu.log
#$ -e workflow-after-gpu.err
#$ -j y
#$ -N after-basecalling-workflow
#$ -pe smp 1-24
#$ -V -cwd
set -e

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=24}

OUTDIR=$1
FAST5DIR=$2

set -u

thisDir=$(dirname $0);
#echo '$thisDir set to:' $thisDir
thisScript=$(basename $0);
#echo '$thisScript set to:' $thisScript
export PATH=$thisDir/../scripts:$PATH
#echo '$PATH is set in this order:'
#echo $PATH | tr ":" "\n" | nl

# check to see if OUTDIR argument is empty, if so exit script
if [ "$OUTDIR" == "" ]; then
    echo "Please supply the path to the output directory from basecalling with the run_basecall-w-gpu.sh script"
    echo ""
    echo "Usage: $thisScript outdir/"
    echo ""
    echo "This workflow runs the following on barcodes 01-24:"
    echo ""
    echo "-filtlong	removes reads <500bp and downsamples to 600Mb (roughly 120X for 5Mb genome)"
    echo "-flye		--plasmids and -g 5M options used"
    echo "-racon		polishes 4X with Racon"
    echo "-medaka		polishes once with Medaka using r9.4.1 pore and HAC guppy basecaller profile"
    echo ""
    echo ""
    exit 1;
fi;

# Setup any debugging information
date
hostname

## DON'T THINK I NEED A TMPDIR FOR THIS SCRIPT ##
# Setup tempdir
#tmpdir=$(mktemp -p . -d ONT-ASM.XXXXXX)
#mkdir $tmpdir/log
#echo "$0: temp dir is $tmpdir";

trap ' { echo "END - $(date)"; } ' EXIT

# Removed '-pe smp 1-$NSLOTS' from qsub commands since each of the scripts set differing numbers of threads
# Now that it is demultiplexed, deal with each sample at a time.
for barcodeDir in ${OUTDIR}demux/barcode{01..24}; do

  # make log dir per barcode, for storing qsub log files
  mkdir -pv $barcodeDir/log

  # Prep the sample
  uuid2=$(uuidgen)
  jobName2="filterSample-$uuid2"
  # removed 'qsub -hold_jid $jobName1' since basecalling should already be done
  qsub -N $jobName2 -cwd -o ${barcodeDir}/log/$jobName2.log -j y \
    ${thisDir}/../scripts/np_filter_filtlong.sh ${barcodeDir}/
  
  # Assemble the sample
  uuid3=$(uuidgen)
  jobName3="assemble-$uuid3"
  qsub -hold_jid $jobName2 -N $jobName3 -cwd -o ${barcodeDir}/log/$jobName3.log -j y \
    ${thisDir}/../scripts/np_assemble_flye.sh ${barcodeDir}/

  # Polish the sample with Racon
  uuid4=$(uuidgen)
  jobName4="polish-racon-$uuid4"
  qsub -hold_jid $jobName3 -N $jobName4 -cwd -o ${barcodeDir}/log/$jobName4.log -j y \
   ${thisDir}/../scripts/np_consensus_racon.sh ${barcodeDir}/

  # Polish the sample with Medaka
  uuid5=$(uuidgen)
  jobName5="polish-medaka-$uuid5"
  qsub -hold_jid $jobName4 -N $jobName5 -cwd -o ${barcodeDir}/log/$jobName5.log -j y \
   ${thisDir}/../scripts/np_polish_medaka.sh ${barcodeDir}/
done

