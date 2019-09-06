#!/bin/bash
#$ -o workflow-after-gpu.log
#$ -e workflow-after-gpu.err
#$ -j y
#$ -N wtdbg2
#$ -pe smp 1-36
#$ -V -cwd
set -e

source /etc/profile.d/modules.sh
module purge

NSLOTS=${NSLOTS:=24}

OUTDIR=$1
FAST5DIR=$2

set -u

thisDir=$(dirname $0);
echo '$thisDir set to:' $thisDir
thisScript=$(basename $0);
echo '$thisScript set to:' $thisScript
export PATH=$thisDir/../scripts:$PATH
echo '$PATH is set in this order:'
echo $PATH | tr ":" "\n" | nl

# check to see if OUTDIR argument is empty, if so exit script
if [ "$OUTDIR" == "" ]; then
    echo ""
    echo "Usage: $thisScript outdir/ fast5dir/"
    echo ""
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

### commented out because basecalling on GPU should be done separately, while 
### logged in directly to node 98
#uuid1=$(uuidgen)
#jobName1="basecall-$uuid1"
#qsub -pe smp 1-$NSLOTS -N $jobName1 -cwd -o log/$jobName1.log -j y \
#  01_basecall.sh $OUTDIR $FAST5DIR


# Removed '-pe smp 1-$NSLOTS' from qsub commands since each of the scripts set differing numbers of threads
# Now that it is demultiplexed, deal with each sample at a time.
for barcodeDir in ${OUTDIR}demux/barcode[0-12]*; do

  # Prep the sample
  uuid2=$(uuidgen)
  jobName2="prepSample-$uuid2"
  # removed 'qsub -hold_jid $jobName1' since basecalling should already be done
  qsub -N $jobName2 -cwd -o log/$jobName2.log -j y \
    /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/03_prepSample-w-gpu.sh ${barcodeDir}/
  
  # Assemble the sample
  uuid3=$(uuidgen)
  jobName3="assemble-$uuid3"
  qsub -hold_jid $jobName2 -N $jobName3 -cwd -o log/$jobName3.log -j y \
    /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/np_assemble_flye.sh ${barcodeDir}/

  # Polish the sample with Racon
  uuid4=$(uuidgen)
  jobName4="polish-racon-$uuid4"
  qsub -hold_jid $jobName3 -N $jobName4 -cwd -o log/$jobName4.log -j y \
   /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/np_consensus_racon.sh ${barcodeDir}/

  # Polish the sample with Medaka
  uuid5=$(uuidgen)
  jobName5="polish-medaka-$uuid5"
  qsub -hold_jid $jobName4 -N $jobName5 -cwd -o log/$jobName5.log -j y \
   /scicomp/home/pjx8/github/nanoporeWorkflow/scripts/np_polish_medaka.sh ${barcodeDir}/
done
