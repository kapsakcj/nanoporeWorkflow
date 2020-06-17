# nanoporeWorkflow

Shell scripts and workflows for working with Nanopore data. Submits jobs to CDC's Aspen HPC using `qsub`. 

:warning: Don't bother reading if you aren't working on CDC's servers :warning:

Started by [@lskatz](https://github.com/lskatz), contributions from [@kapsakcj](https://github.com/kapsakcj) and potentially YOU!

## TOC
  * [Scripts](#scripts)
  * [Workflows](#workflows)
    * [Guppy GPU basecalling, demultiplexing, and trimming](#guppy-gpu-basecalling-demultiplexing-and-trimming)
    * [Assembly with Flye and polishing with Racon and Medaka](#assembly-with-flye-and-polishing-with-racon-and-medaka)
  * [Contributing](#contributing)
  * [Future Plans](#future-plans)
  * [Resources](#resources)

## Scripts

This is a collection of scripts that do one thing at a time.  For example, assembling or polishing an assembly [except for `np_basecall-w-gpu.sh` where guppy basecalls and demultiplexes simultaneously ].

Each script should start with `np_` to indicate the nanopore workflow. Then,
each script should be named after one of these namespaces, to help indicate which stage of the process.
Separate each namespace with an underscore. Namespaces may not have underscores
in their names (e.g., a namespace of de_multiplex would be invalid.).

* basecalling: `basecall` (can be combined with basecalling: `basecall-demux`)
* demultiplexing: `demux_` (can be combined with basecalling: `basecall-demux`)
* preparing the data in each barcode: `prepSample_`
* assembly: `assemble_`
* polishing: `polish_`

## Workflows

This is a collection of workflows in the form of shell scripts.  They `qsub` the scripts individually.

### Guppy GPU basecalling, demultiplexing, and trimming

`run_basecall-w-gpu.sh` - Guppy GPU basecalling, demultiplexing, and adapter/barcode trimming with `guppy_basecaller`

`run_basecall-w-gpu.sh` is the runner/driver script for `np_basecall-w-gpu.sh`

#### Requirements

  * Must be logged into a server with the ability to run `qsub` for submitting jobs to Aspen:
    * Aspen head node
    * Aspen interactive node (run  `qlogin` from aspen head node)
    * Monoliths 1-3 (cannot submit jobs from M4)
  * Currently supported MinION data:
    * R9.4.1 flowcell (FLO-MIN106)
      * Rapid barcoding kit (RBK-004)
      * Ligation sequencing kit (SQK-LSK109) + native barcodes 1-24 (NBD103/104/114)
    * R10 flowcell
      * Ligation sequencing kit (SQK-LSK109) + native barcodes 1-24 (NBD103/104/114)
  *  Unsupported combos (want to add in the future!):
      * R9.4.1 + rapid or ligation sequencing kit without barcoding (RAD-004)
      * R10 + ligation without barcoding 
      * R10.3 + ligation with & without barcoding

#### This workflow does the following:
  * Takes in 5 arguments:
    1. `-i path/to/fast5files/`      - the input directory containing raw fast5 files
    2. `-o path/to/outputDirectory/` - an output directory
    3. `-b y || yes || n || no`      - were barcodes used?
    4. `-f r941 || r10`              - flowcell type used?
    5. `-k rapid || ligation`         - sequencing kit used?
  * copies fast5s from input directory to `/tmp/$USER/guppy.gpu.XXXXXX`
  * runs `guppy_basecaller` in `hac` or high-accuracy mode on GPUs
  * Demultiplexes using `guppy_basecaller` and additionally trims adapter and barcode sequences (using `--trim_barcodes ; --barcode_kits "EXP-NBD104 EXP-NBD114" or "SQK-RBK004"` options)
  * Compresses (gzip) the demultiplexed reads (`--compress_fastq` option)
  * Copies demultiplexed, trimmed, compressed reads into subdirectories in `$OUTDIR/demux/barcodeXX`
 
#### INSTALL
Download the repository from the latest release (v0.4.4 is latest as of 17 June 2020) and uncompress.
```bash
$ wget https://github.com/lskatz/nanoporeWorkflow/archive/v0.4.4.tar.gz 
$ tar -xzf v0.4.4.tar.gz
 ```
Optionally add the workflows to your $PATH (edit the PATH below to wherever you downloaded the repo). Refresh your environment.
```bash
# Be careful with this command - make sure the PATH is properly edited!
$ echo 'export PATH=$PATH:/path/to/nanoporeWorkflow-0.4.4/workflows' >> ~/.bashrc
$ source ~/.bashrc
```
 #### USAGE:
```bash
Usage: /path/to/nanoporeWorkflow-0.4.4/workflows/run_basecall-w-gpu.sh
                 -i path/to/fast5files/        
                 -o path/to/outputDirectory/   
                 -b y || yes || n || no        barcodes used?
                 -f r941 || r10                flowcell type used?
                 -k rapid || ligation          sequencing kit used?

example: /path/to/nanoporeWorkflow-0.4.4/workflows/run_basecall-w-gpu.sh -i fast5s/ -o output/ -b y -f r941 -k rapid

# EXAMPLE OUTPUT (reduced for brevity)
$OUTDIR
├── demux
│   ├── barcode01
│   │   └── fastq_runid_fbc8eee46271cbe60ee8a49d0ca657f6e92e174e_0_0.fastq.gz (there will be many .fastq.gz files per barcode)
│   ├── barcode02
│   │   └── fastq_runid_fbc8eee46271cbe60ee8a49d0ca657f6e92e174e_0_0.fastq.gz
│   ├── barcode03
│   │   └── fastq_runid_fbc8eee46271cbe60ee8a49d0ca657f6e92e174e_0_0.fastq.gz
│   ├── guppy-logs
│       └── guppy_basecaller_log-2020-04-17_09-45-00.log (there will be many guppy-logs)
│   ├── nanoplot
│       └── NanoPlot-report.html # additionally all images and other files produced by NanoPlot
│   ├── nanoplot-barcoded
│       └── NanoPlot-report.html # additionally all images and other files produced by NanoPlot, but for each barcode
│   ├── sequencing_summary.txt
│   ├── sequencing_telemetry.js
│   └── unclassified
│       └── fastq_runid_fbc8eee46271cbe60ee8a49d0ca657f6e92e174e_0_0.fastq.gz
└── log # qsub logs
    └── guppy.log
    └── nanoplot.log
```

### Assembly with Flye and polishing with Racon and Medaka

#### This workflow does the following:
  * Takes in 1 argument:
    1. `$outdir` - The output directory from running `run_basecall-w-gpu.sh`, containing `demux/barcodeXX/` directories
  * Prepares a barcoded sample - concatenates all fastq files into one, compresses, and counts read lengths
  * Runs `filtlong` via singularity to remove reads <500bp and downsample reads to 600 Mb (roughly 120X for a 5 Mb genome)
  * Assembles downsampled/filtered reads using `Flye` via singularity (`--plasmids` and `-g 5M` options used)
  * Polishes flye draft assembly using racon 4 times
  * Polishes racon polished assembly using Medaka (specific to r9.4.1 flowcell, high accuracy basecaller model, and guppy version 3.6.x, `--m r941_min_high_g360` option used)

#### Requirements
  * Must have previously run the above script that basecalls reads on a GPU node.
  * Must be logged into a server with the ability to `qsub` (Aspen, Monoliths 1-3).
  * `OUTDIR` argument must be the same directory as the `OUTDIR` from the gpu-basecalling script

#### USAGE
```bash
# note: ensure that the outdir supplied in this command is the exact same as the outdir you
# supplied when you ran the run_basecall-w-gpu.sh script
Usage: /path/to/nanoporeWorkflow-0.4.4/workflows/workflow-after-gpu-basecalling.sh outdir/

# EXAMPLE OUTPUT - only showing one barcode for brevity
$OUTDIR/
├── demux
│   ├── barcode01
│   │   ├── all.fastq.gz
│   │   ├── flye
│   │   ├── log  # qsub logs for each barcode
│   │   │   ├── assemble-d64ffbc5-4012-44c5-8191-1a57d4a7d15c.log
│   │   │   ├── polish-medaka-00e52c16-0bd3-460d-b955-3a532be958b1.log
│   │   │   ├── polish-racon-d7ebc124-d100-43e0-b347-1e60bbc0bf18.log
│   │   │   └── prepSample-7ecc6f51-4937-40d1-a6bd-d83e66078984.log
│   │   ├── medaka
│   │   ├── racon
│   │   ├── readlengths.txt.gz
│   │   └── reads.minlen1000.600Mb.fastq.gz
│   ├── guppy-logs
│   ├── nanoplot
│   ├── nanoplot-barcoded
│   ├── sequencing_summary.txt
│   ├── sequencing_telemetry.js
│   └── unclassified
└── log # qsub logs
    └── guppy.log
    └── nanoplot.log
```
#### Notes on assembly and polishing workflow
  * It will check for the following files, to determine if it should skip any of the steps. Helps if one part doesn't run correctly and you don't want to repeat a certain step, e.g. re-assembling.
    * `np_filter_filtlong.sh` looks for `./demux/barcodeXX/reads.minlen500.600Mb.fastq.gz` 
    * `np_assemble_flye.sh` looks for `./demux/barcodeXX/flye/assembly.fasta`
    * `np_consensus_racon.sh` looks for `./demux/barcodeXX/racon/ctg.consensus.iteration4.fasta`
    * `np_polish_medaka.sh` looks for `./demux/barcodeXX/medaka/polished.fasta`

## Contributing
If you are interested in contributing to nanoporeWorkflow, please take a look at the [contribution guidelines](CONTRIBUTING.md). We welcome issues or pull requests!

## Future plans 
* Add support for passing in a config file to `workflow-after-gpu-basecalling.sh` that contains:
  * Sample ID
  * barcode number (RBK or NBD)
  * estimated genome size (to be used as input parameter in various places)
* Allow users to specify a read length for removing reads w/ `filtlong`
* Test and add support for `rasusa` for randomly subsampling and filtering reads (`filtlong` is biased towards reads with highest q-scores)
* add flags/options for other sequencing kits, barcoding kits, flowcells (direct RNAseq?)
  * **R10.3** + ligation with native barcodes 1-24 (R10 flowcell discontinued)
* Add option for Medaka polishing with r941_min_fast model, if reads were basecalled with the fast Guppy model
  
## Resources
  * https://github.com/fenderglass/Flye
  * https://github.com/isovic/racon
  * https://github.com/nanoporetech/medaka
  * https://github.com/nanoporetech/qcat
  * How to set Guppy parameters (requires Nanopore Community login credentials) https://community.nanoporetech.com/protocols/Guppy-protocol/v/gpb_2003_v1_revl_14dec2018/how-to-configure-guppy-parameters
