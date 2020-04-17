#!/bin/bash
#$ -o guppy-gpu.log
#$ -e guppy-gpu.err
#$ -j y
#$ -jc guppy
#$ -N guppy-gpu
#$ -V -cwd

# removed -pe smp 2-20 since all GPU nodes have 20 CPUs

# Curtis Kapsak pjx8@cdc.gov

# Defaulting to high-accuracy mode for Guppy. 
# Guppy will produce demultiplexed, trimmed, and gzipped fastqs.

# This function will check to make sure the directory doesn't already exist before trying to create it
make_directory() {
    if [ -e $1 ]; then
        echo "Directory "$1" already exists"
    else
        mkdir -pv $1
    fi
}

set -e

source /etc/profile.d/modules.sh
module purge

# GPU nodes have 20 threads
NSLOTS=${NSLOTS:=20}

# Setup any debugging information
date
hostname
echo '$USER is set to:' $USER

# Setup tmpdir in /scratch
# Cory recommended this since it will be faster than NFS GWA storage, lower latency as well
tmpdir=$(mktemp -p /tmp/$USER/ -d guppy.gpu.XXXXXX)

# This prints when the script ended and will cleanup the $tmpdir present in /scratch/$USER before exiting
trap ' { echo "END - $(date)"; rm -rf $tmpdir; } ' EXIT
make_directory $tmpdir/log
echo "$0: temp dir is $tmpdir";

# copy fast5s to $tmpdir
make_directory $tmpdir/fast5
fast5tmp=$tmpdir/fast5
echo '$fast5tmp dir is set to:' $fast5tmp
# check to see if basecalling/demultiplexing has been done and files exist in OUTDIR
# if not, copy files into fast5tmp and begin
if [[ -e  ${OUTDIR}demux/ ]]; then
    echo "Demuxed fastqs present in OUTDIR. Exiting script..."
    exit 0
else
    echo "Copying reads from $FAST5DIR to $tmpdir"
    cp -r $FAST5DIR $fast5tmp
fi


#### Basecalling using GPU ####
module load guppy/3.4.5

# moved this line below loading guppy module since a variable in /apps/x86_64/fast5/2.0.1/bin/activate does not get set
set -u

# defaulting to guppy in high-accuracy mode
# should return version 3.4.5
guppy_basecaller -v

# check to see if basecalling has been done by checking OUTDIR/demux/ for sequencing_summary.txt
if [[ -e $OUTDIR/demux/sequencing_summary.txt ]]; then
  echo "FAST5 files have already been basecalled. Skipping."
else
  # R10 -c dna_r10_450bps_hac.cfg
  if [[ "$FLOWCELL" == "r10" ]]; then
    if [[ "$BARCODE" == "yes" ]]; then
      # different barcode arguments
      if [[ "$SEQKIT" == "rapid" ]]; then
        echo "r10 yesBarcode rapid"
        echo "R10 and rapid kit don't play well - this likely won't be an option for a while"
      # R10, ligation, native barcoding
      elif [[ "$SEQKIT" == "ligation" ]]; then
         guppy_basecaller -i $fast5tmp \
                       -s $tmpdir/demux \
                       --hp_correct yes \
                       -r \
                       -c dna_r10_450bps_hac.cfg \
                       --gpu_runners_per_device 8 \
                       --chunks_per_runner 256 \
                       --num_callers 8 \
                       --compress_fastq \
                       --trim_barcodes \
                       --barcode_kits "EXP-NBD104" \
                       --num_barcode_threads 8 \
                       -x auto 
      fi
    elif [[ "$BARCODE" == "no" ]]; then
      # same guppy command for rapid and ligation -c dna_r10_450bps_hac.cfg
      echo "r10 noBarcode either ligation/rapid"
      echo "WARNING THIS MODE IS UNTESTED"
      # WARNING: this has not been tested - don't have test dataset. I copied the guppy command from above without barcode flags
         guppy_basecaller -i $fast5tmp \
                       -s $tmpdir/demux \
                       --hp_correct yes \
                       -r \
                       -c dna_r10_450bps_hac.cfg \
                       --gpu_runners_per_device 8 \
                       --chunks_per_runner 256 \
                       --num_callers 8 \
                       --compress_fastq \
                       -x auto
    fi
  # R941 -c dna_r9.4.1_450bps_hac.cfg
  elif [[ "$FLOWCELL" == "r941" ]]; then
    if [[ "$BARCODE" == "yes" ]]; then    
      # R941, rapid, rapid barcoding 
      if [[ "$SEQKIT" == "rapid" ]]; then
         guppy_basecaller -i $fast5tmp \
                       -s $tmpdir/demux \
                       --hp_correct yes \
                       -r \
                       -c dna_r9.4.1_450bps_hac.cfg \
                       --gpu_runners_per_device 2 \
                       --chunks_per_runner 1000 \
                       --num_callers 8 \
                       --compress_fastq \
                       --trim_barcodes \
                       --barcode_kits "SQK-RBK004" \
                       --num_barcode_threads 8 \
                       -x auto 
      # R941, ligation, native barcoding 
      elif [[ "$SEQKIT" == "ligation" ]]; then
         guppy_basecaller -i $fast5tmp \
                       -s $tmpdir/demux \
                       --hp_correct yes \
                       -r \
                       -c dna_r9.4.1_450bps_hac.cfg \
                       --gpu_runners_per_device 2 \
                       --chunks_per_runner 1000 \
                       --num_callers 8 \
                       --compress_fastq \
                       --trim_barcodes \
                       --barcode_kits "EXP-NBD104" \
                       --num_barcode_threads 8 \
                       -x auto
      fi
    # same guppy command for rapid and ligation -c dna_r9.4.1_450bps_hac.cfg
    elif [[ "$BARCODE" == "no" ]]; then  
      echo "r941 noBarcode either ligation/rapid"
      echo "WARNING THIS MODE IS UNTESTED"
      # This guppy command is untested - I have test data for this but haven't tested yet
      guppy_basecaller -i $fast5tmp \
                       -s $tmpdir/demux \
                       --hp_correct yes \
                       -r \
                       -c dna_r9.4.1_450bps_hac.cfg \
                       --gpu_runners_per_device 2 \
                       --chunks_per_runner 1000 \
                       --num_callers 8 \
                       --compress_fastq \
                       -x auto
    fi
  fi
fi

  
# if ligation kit was used, use this guppy command for native barcoding kit 
# SQK-LSK109 + EXP-NBD104, EXP-NBD114 is barcodes 13-24. EXP-NBD103 is the same as EXP-NBD104.
# EXP-NBD104 is newer and will be around longer as an option in guppy 
# will currently use NBD103 and NBD104 but will add in NBD114 later if people use them
# See: https://community.nanoporetech.com/posts/native-barcoding-expansion


# copy demuxed fastqs into the specified OUTDIR
if [[ -e $OUTDIR/demux/none.fastq ]]; then
  echo "Demuxed fastqs have been transferred from tmpdir to OUTDIR. Skipping."
else
  echo "Copying reads from $tmpdir to $OUTDIR"
  cp -r $tmpdir/demux $OUTDIR
fi

