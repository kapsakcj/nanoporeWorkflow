# nanoporeWorkflow

## scripts

This is a collection of scripts that do one thing at a time.  For example, demultiplexing or basecalling.

## workflows

This is a collection of workflows in the form of shell scripts.  They qsub the scripts individually.
The first positional parameter must be the project folder.  Both input and output go to the project folder.

### Workflow 1: `run_01_basecall-w-gpu.sh` - `guppy` GPU basecalling and demultiplexing with `qcat`
`run_01_basecall-w-gpu.sh` is the runner/driver script for `01_basecall-w-gpu.sh`

#### Requirements
  * Must be run while logged into directly node98 (Tesla V100 GPUs will eventually be a part of `qsub`, but are not currently, do NOT use qsub or run script on another node _unless it has a V100 GPU installed_)
  * No one else must be running stuff on the node - this Guppy command will eat up all GPU resources
    * check CPU usage with `htop` and GPU usage with `nvtop` before running the script
  * Must be MinION data, generated with an R9.4.1 flowcell (FLO-MIN106) and ligation sequencing kit (SQK-LSK109)
    * Must be Native Barcodes 1-24 (NBD103/104/114)

#### This workflow does the following:
  * Takes in 3 arguments (in this order):
    1. `$OUTDIR` - an output directory
    2. `$FAST5DIR` - a directory containing raw fast5 files
    3. `$MODE` - basecalling mode/configuration - either `fast` or `hac` (high accuracy)
  * copies fast5s from `$FAST5DIR` to `/tmp/$USER/guppy.gpu.XXXXXX`
  * runs `guppy_basecaller` in either `fast` or `hac` mode
    * According to ONT - High accuracy mode will take anywhere from 5-8X longer to complete basecalling than fast mode, but will result in 2-3% higher read accuracy. 
  * Demultiplexes using `qcat` and additionally trims adapter and barcode sequences (using `--trim` option w/ `qcat`)
  * Copies demultiplexed & trimmed reads into subdirectories in `$OUTDIR/demux/barcodeXX`
  * Logs STDOUT from last time script was ran in `$OUTDIR/log/logfile-gpu-basecalling.txt` and all previous times in `$OUTDIR/log/logfile-gpu-basecalling_prev.txt`
 
 #### USAGE:
```bash
cd ~/
# download the scripts
# TODO - CHANGE THIS TO DL A SPECIFIC RELEASE
git clone https://github.com/lskatz/nanoporeWorkflow.git

# Specified dirs MUST end with a '/'
Usage: 
# fast mode
    ~/nanoporeWorkflow/workflows/run_01_basecall-w-gpu.sh outdir/ fast5dir/ fast
# high accuracy mode
    ~/nanoporeWorkflow/workflows/run_01_basecall-w-gpu.sh outdir/ fast5dir/ hac

# OUTPUT
$OUTDIR
├── demux
│   ├── barcode06
│   │   └── barcode06.fastq
│   ├── barcode10
│   │   └── barcode10.fastq
│   ├── barcode12
│   │   └── barcode12.fastq
│   ├── none.fastq
│   └── sequencing_summary.txt
└── log
    ├── logfile-gpu-basecalling_prev.txt # only present if you ran the script more than once
    └── logfile-gpu-basecalling.txt
```
 
#### Future plans/To-do:
  * Compress demuxed reads using `pigz`. Latest release of Guppy v 3.1.5 (not available/installed on node98) includes an option for producing gzipped reads, but is not yet installed on node 98.
  * add flags/options for other sequencing kits, barcoding kits, flowcells (direct RNAseq?)
  
### Resources
  * https://github.com/nanoporetech/qcat
  * How to set Guppy parameters (requires Nanopore Community login credentials) https://community.nanoporetech.com/protocols/Guppy-protocol/v/gpb_2003_v1_revl_14dec2018/how-to-configure-guppy-parameters
  * 
