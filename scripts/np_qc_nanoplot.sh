#!/bin/bash
#$ -o nanoplot.log
#$ -j y
#$ -N nanoplot
#$ -pe smp 2-18
#$ -V -cwd
set -e

# This script will take the output of np_basecall-w-gpu.sh and generate run summary
# statistics, plots, and an html report using NanoPlot

### REQUIREMENTS:
# singularity
# access to nanoplot singularity image at /apps/standalone/singularity/nanoplot/nanoplot.1.29.0.staphb.simg

function HELP {
echo ""
echo "Usage: $0 outdir/ yes||no"
echo ""
echo "The first argument must be the output directory from run-basecall-w-gpu.sh."
echo "outdir/demux/sequencing_summary.txt must be present."
echo ""
echo "The second argument must be either 'yes' or 'no' to indicate if barcodes were used or not."
exit 0
}

#This function will check to make sure the directory doesn't already exist before trying to create it
make_directory() {
    if [ -e $1 ]; then
        echo "Directory "$1" already exists"
    else
        mkdir $1
        echo "Directory "$1" has been created"
    fi
}

NSLOTS=${NSLOTS:=18}
echo '$NSLOTS set to:' $NSLOTS

# INDIR should be the output dir from run_basecall-w-gpu.sh script
# INDIR should have $INDIR/demux/ subdirectory
# need to be able to access demux/sequencing_summary.txt and demux/sequencing_telemetry.js

# check to make sure INDIR isn't a blank string
INDIR=$OUTDIR
if [ "$INDIR" == "" ]; then
    INDIR=$1
    if [ "$INDIR" == "" ]; then
        HELP
    fi
fi
echo '$INDIR is set to:' $INDIR

# check to make sure second argument (BARCODE) is set
# should be set when running run_basecall-w-gpu.sh, but if running this script
# manually, it will need to be set.
if [ "$BARCODE" = "" ]; then
  BARCODE=$2
  # show HELP if user still did not supply second argument
  if [ "$BARCODE" == "" ]; then
    echo "enter yes or no as the second argument to specify if barcodes were used or not"
    HELP
  fi
fi
echo '$BARCODE is set to ' $BARCODE

# check to make sure sequencing_summary.txt exists, if not show help and exit
if [[ ! -f ${INDIR}/demux/sequencing_summary.txt  ]]; then
    echo "outdir/demux/sequencing_summary.txt not found. Please adjust the path of your supplied output directory"
    HELP
fi

set -u

# Setup any debugging information
date
hostname

# upon exit, print END folowed by date
trap ' { echo "END - $(date)"; } ' EXIT

# check to see if nanoplot report has already been generated, skip if so
if [ -f ${INDIR}/demux/nanoplot/*NanoPlot-report.html ]; then
  echo "NanoPlot report and plots have already been generated for this run. Skipping...."
  exit 0
fi

# Using Singularity container since it has NanoPlot 1.29.0. latest version available in module system is 1.28.0
source /etc/profile.d/modules.sh
module purge
module load singularity/3.5.3

# pull the 'sample_id' key and value from a guppy_output file. Represents the runID (at least for Jenny's runs)
# grep -m stops searching after first occurrence. cut to pull the value of the sample_id key
runID=$(grep -m 1 'sample_id' ${INDIR}/demux/sequencing_telemetry.js | cut -d '"' -f 4)
echo '$runID is set to:' $runID

# run NanoPlot
# 100kb max to make the plots look nicer when there are a few reads >100kb
echo "Running NanoPlot via singularity container..."
singularity exec --no-home -B ${INDIR}:/data /apps/standalone/singularity/nanoplot/nanoplot.1.29.0.staphb.simg \
   NanoPlot --summary /data/demux/sequencing_summary.txt -o /data/demux/nanoplot -t $NSLOTS --loglength --N50 --prefix ${runID}- --maxlength 100000

# run NanoPlot --barcoded, to get barcoded stats (and individual barcode plots if interested in investigating a barcode further)
# if barcodes were used, additionally run NanoPlot --barcoded
if [[ "$BARCODE" == "yes" ]]; then
  echo "User specified that barcodes were used. Running NanoPlot --barcoded via singularity container..."
  singularity exec --no-home -B ${INDIR}:/data /apps/standalone/singularity/nanoplot/nanoplot.1.29.0.staphb.simg \
  NanoPlot --barcoded --summary /data/demux/sequencing_summary.txt -o /data/demux/nanoplot-barcoded -t $NSLOTS --loglength --N50 --prefix ${runID}- --maxlength 100000
else
  echo "User specified that barcodes were not used. Skipping NanoPlot --barcoded"
fi
