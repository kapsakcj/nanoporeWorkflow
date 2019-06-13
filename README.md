# nanoporeWorkflow

Shell scripts and workflows for working with Nanopore data. Most scripts use `qsub`, the GPU basecalling script does not.

Started by [@lskatz](https://github.com/lskatz), contributions from [@kapsakcj](https://github.com/kapsakcj) and potentially YOU!

## TOC
  * [Scripts](#scripts)
  * [Workflows](#workflows)
    * [Guppy GPU basecalling and demultiplexing with qcat](#guppy-gpu-basecalling-and-demultiplexing-with-qcat)
    * [Assembly with wtdbg2 and polishing with Nanopolish](#assembly-with-wtdbg2-and-polishing-with-nanopolish)
  * [Contributing](#contributing)
  * [Future Plans](#future-plans)
  * [Resources](#resources)

## Scripts

This is a collection of scripts that do one thing at a time.  For example, demultiplexing or basecalling [except for `01_basecall-w-gpu.sh` which does both :) ].

## Workflows

This is a collection of workflows in the form of shell scripts.  They `qsub` the scripts individually (except for `run_basecalling-w-gpu.sh` since the GPUs aren't available through `qsub` yet).

For `workflow.sh` the first positional parameter must be the project folder.  Both input and output go to the project folder.

### Guppy GPU basecalling and demultiplexing with qcat

`run_01_basecall-w-gpu.sh` - `guppy` GPU basecalling (& adapter trimming) and demultiplexing (& adapter/barcode trimming) with `qcat`

`run_01_basecall-w-gpu.sh` is the runner/driver script for `01_basecall-w-gpu.sh`

#### Requirements
  * Must be run while logged into directly node98 (Tesla V100 GPUs will eventually be a part of `qsub`, but are not currently, do NOT use qsub or run script on another node _unless it has a V100 GPU installed_)
  * No one else must be running stuff on the node - this Guppy command will eat up all GPU resources
    * check CPU usage with `htop` and GPU usage with `nvtop` before running the script
  * Must be MinION data, generated with an R9.4.1 flowcell (FLO-MIN106) and ligation sequencing kit (SQK-LSK109)
    * Must be Native Barcodes 1-24 (NBD103/104/114)
    * We'd like to add flags for other flowcells and sequencing kit when we come across data from those!

#### This workflow does the following:
  * Takes in 3 arguments (in this order):
    1. `$OUTDIR` - an output directory
    2. `$FAST5DIR` - a directory containing raw fast5 files
    3. `$MODE` - basecalling mode/configuration - either `fast` or `hac` (high accuracy)
  * copies fast5s from `$FAST5DIR` to `/tmp/$USER/guppy.gpu.XXXXXX`
  * runs `guppy_basecaller` in either `fast` or `hac` mode
    * According to ONT - High accuracy mode will take anywhere from 5-8X longer to complete basecalling than fast mode, but will result in 2-3% higher read accuracy. 
  * Demultiplexes using `qcat` and additionally trims adapter and barcode sequences (using `--trim` option w/ `qcat`)
  * Compresses (gzip) the demultiplexed reads
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
│   │   └── barcode06.fastq.gz
│   ├── barcode10
│   │   └── barcode10.fastq.gz
│   ├── barcode12
│   │   └── barcode12.fastq.gz
│   ├── none.fastq.gz
│   └── sequencing_summary.txt
└── log
    ├── logfile-gpu-basecalling_prev.txt # only present if you ran the script more than once
    └── logfile-gpu-basecalling.txt
```

### Assembly with wtdbg2 and polishing with Nanopolish

#### This workflow does the following:
  * Takes in 2 arguments (in this order):
    1. `$outdir` - an output directory
    2. `$FAST5DIR` - a directory containing raw fast5 files
  * Prepares a barcoded sample - concatenates all fastq files into one, compresses, and counts read lengths
  * Assembles using wtdbg2
  * Polishes using nanopolish

#### Requirements
  * Must have previously run the above script that basecalls reads on a GPU via node98.
  * Not necessary to be on node98. Any server with the ability to `qsub` will work.
  * `outdir` argument must be the same directory as the `OUTDIR` from the gpu-basecalling script
    * Recommend `cd`'ing to that directory and use `.` as the `outdir` argument (see USAGE below)

#### USAGE
```bash
Usage: 
    # use your favorite queue, doesn't have to be all.q
    qsub -q all.q ~/nanoporeWorkflow/workflows/workflow-after-gpu-basecalling.sh outdir/ fast5dir/

    # example - if you are in your output directory from the gpu-basecalling script
    cd outdir/
    qsub -q all.q ~/nanoporeWorkflow/workflows/workflow-after-gpu-basecalling.sh . ../FAST5/

# OUTPUT
$OUTDIR
├── demux
│   ├── barcode12 # only showing one barcode for brevity
│   │   ├── all-barcode12.fastq.gz
│   │   ├── all-barcode12.fastq.gz.index
│   │   ├── all-barcode12.fastq.gz.index.fai
│   │   ├── all-barcode12.fastq.gz.index.gzi
│   │   ├── all-barcode12.fastq.gz.index.readdb
│   │   ├── consensus.ctg1:0-11000.log # A LOT OF THESE, for each chunk of each contig
│   │   ├── consensus.ctg1:0-11000.vcf.gz # A LOT OF THESE, for each chunk of each contig
│   │   ├── polished.fasta
│   │   ├── rangesCounter.txt
│   │   ├── readlengths.txt.gz
│   │   ├── reads.bam
│   │   ├── reads.bam.bai
│   │   ├── unpolished.fasta
│   │   ├── unpolished.fasta.fai
│   │   ├── wtdbg2.1.dot.gz
│   │   ├── wtdbg2.1.nodes
│   │   ├── wtdbg2.1.reads
│   │   ├── wtdbg2.2.dot.gz
│   │   ├── wtdbg2.3.dot.gz
│   │   ├── wtdbg2.alignments.gz
│   │   ├── wtdbg2.binkmer
│   │   ├── wtdbg2.closed_bins
│   │   ├── wtdbg2.clps
│   │   ├── wtdbg2.ctg.dot.gz
│   │   ├── wtdbg2.ctg.lay.gz
│   │   ├── wtdbg2.events
│   │   ├── wtdbg2.frg.dot.gz
│   │   ├── wtdbg2.frg.nodes
│   │   └── wtdbg2.kmerdep
└── log
    ├── prepSample-35d239ad-f2c3-4472-b810-76f56ad43c1d.log # one of each of these logs for each barcode
    ├── assemble-f73c45e5-ceb4-4aae-bc13-c9923adfe63a.log
    └── polish-c1888109-727b-4a99-bc92-69c12e97222e.log
```
#### Notes on assembly and polishing workflow
  * It will check for the following files, to determine if it should skip any of the steps. Helps if one part doesn't run correctly and you don't want to repeat a certain step, e.g. re-assembling.
    * `03_preppSample-w-gpu.sh` looks for `./demux/barcodeXX/all-barcodeXX.fastq.gz` 
    * `05_assemble.sh` looks for `./demux/barcodeXX/unpolished.fasta`
    * `07_nanopolish.sh` looks for `./demux/barcodeXX/polished.fasta`

## Contributing
If you are interested in contributing to nanoporeWorkflow, please take a look at the [contribution guidelines](CONTRIBUTING.md). We welcome issues or pull requests!

## Future plans
  * add flags/options for other sequencing kits, barcoding kits, flowcells (direct RNAseq?)
  
## Resources
  * https://github.com/nanoporetech/qcat
  * How to set Guppy parameters (requires Nanopore Community login credentials) https://community.nanoporetech.com/protocols/Guppy-protocol/v/gpb_2003_v1_revl_14dec2018/how-to-configure-guppy-parameters

