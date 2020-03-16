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

This is a collection of scripts that do one thing at a time.  For example, assembling or polishing an assembly [except for `01_basecall-w-gpu.sh` where guppy basecalls and demultiplexes simultaneously ].

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

For `workflow.sh` the first positional parameter must be the project folder.  Both input and output go to the project folder.

### Guppy GPU basecalling, demultiplexing, and trimming

`run_01_basecall-w-gpu.sh` - Guppy GPU basecalling, demultiplexing, and adapter/barcode trimming with `guppy_basecaller`

`run_01_basecall-w-gpu.sh` is the runner/driver script for `01_basecall-w-gpu.sh`

#### Requirements

  * Must be logged into a server with the ability to run `qsub` for submitting jobs to Aspen (Biolinux, Monoliths, Aspen head node)
  * Currently supported MinION data:
    * R9.4.1 flowcell (FLO-MIN106)
      * Rapid barcoding kit (RBK-004)
      * Ligation sequencing kit (SQK-LSK109) + native barcodes 1-24 (NBD103/104/114)
    * R10 flowcell
      * Ligation sequencing kit (SQK-LSK109) + native barcodes 1-24 (NBD103/104/114)
    * Currently unsupported combos (want to add in the future!):
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
  * copies fast5s from input directory to `/scratch/$USER/guppy.gpu.XXXXXX`
  * runs `guppy_basecaller` in `hac` mode on GPUs
  * Demultiplexes using `guppy_basecaller` and additionally trims adapter and barcode sequences (using `--trim_barcodes ; --barcode_kits "EXP-NBD103" or "SQK-RBK004"` options)
  * Compresses (gzip) the demultiplexed reads (`--compress_fastq` option)
  * Copies demultiplexed, trimmed, compressed reads into subdirectories in `$OUTDIR/demux/barcodeXX`
 
 #### USAGE:
```bash
# download the scripts, ignoring the test data stored via git-lfs
$ GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/lskatz/nanoporeWorkflow.git 

# TODO - download the repo from a release, once one is made

# optionally add the workflows to your $PATH (edit the PATH below to wherever you cloned the repo)
$ echo 'export PATH=$PATH:/path/to/nanoporeWorkflow/workflows' >> ~/.bashrc
# refresh your environment
$ source ~/.bashrc

Usage: ../nanoporeWorkflow/workflows/run_01_basecall-w-gpu.sh
                 -i path/to/fast5files/        
                 -o path/to/outputDirectory/   
                 -b y || yes || n || no        barcodes used?
                 -f r941 || r10                flowcell type used?
                 -k rapid || ligation          sequencing kit used?

example: ../nanoporeWorkflow/workflows/run_01_basecall-w-gpu.sh -i fast5s/ -o output/ -b y -f r941 -k rapid

# OUTPUT
$OUTDIR
├── demux
│   ├── barcode06
│   │   └── barcode06.fastq.gz (there will be many .fastq.gz files per barcode)
│   ├── barcode10
│   │   └── barcode10.fastq.gz
│   ├── barcode12
│   │   └── barcode12.fastq.gz
│   ├── none.fastq.gz
|   └── sequencing_summary.txt

```

### Assembly with Flye and polishing with Racon and Medaka

#### This workflow does the following:
  * Takes in 1 argument:
    1. `$outdir` - The output directory from running `run_01_basecall-w-gpu.sh`, containing `demux/barcodeXX/` directories
  * Prepares a barcoded sample - concatenates all fastq files into one, compresses, and counts read lengths
  * Runs `filtlong` via singularity to remove reads <1000bp and downsample reads to 600 Mb (roughly 120X for a 5 Mb genome)
  * Assembles downsampled/filtered reads using `Flye` via singularity (`--plasmids` and `-g 5M` options used)
  * Polishes flye draft assembly using racon 4 times
  * Polishes racon polished assembly using Medaka via singularity (specific to r9.4.1 flowcell and high accuracy basecaller, `--m r941_min_high` option used)

#### Requirements
  * Must have previously run the above script that basecalls reads on a GPU node.
  * Not necessary to be on node98. Any server with the ability to `qsub` will work.
  * `outdir` argument must be the same directory as the `OUTDIR` from the gpu-basecalling script
    * Recommend `cd`'ing to one directory above and use `.` as the `outdir` argument (see USAGE below)

#### USAGE
```bash
Usage: 
    # example - if you are one directory above the output directory from the gpu-basecalling script
    ~/nanoporeWorkflow/workflows/workflow-after-gpu-basecalling.sh outdir/

# OUTPUT - only showing one barcode for brevity, not all files included
$OUTDIR
demux/
├── barcode07
│   ├── all.fastq.gz
│   ├── flye
│   ├── medaka
│   ├── racon
│   ├── readlengths.txt.gz
│   └── reads.minlen1000.600Mb.fastq.gz
└── log
log/
├── assemble-13f6870a-e7ab-4475-8acc-6762e57e5d55.log # one of each of these logs for each barcode
├── polish-medaka-3d22f12c-8a50-4dd7-9cc6-7c1bc5098b48.log
├── polish-racon-6c22aa55-5a95-4d17-9a01-abeade24b431.log
└── prepSample-157680be-7f14-4a32-8a74-4bfe5de0b624.log
```
#### Notes on assembly and polishing workflow
  * It will check for the following files, to determine if it should skip any of the steps. Helps if one part doesn't run correctly and you don't want to repeat a certain step, e.g. re-assembling.
    * `03_prepSample-w-gpu.sh` looks for `./demux/barcodeXX/reads.minlen1000.600Mb.fastq.gz` 
    * `np_assemble_flye.sh` looks for `./demux/barcodeXX/flye/assembly.fasta`
    * `np_consensus_racon.sh` looks for `./demux/barcodeXX/racon/ctg.consensus.iteration4.fasta`
    * `np_polish_medaka.sh` looks for `./demux/barcodeXX/medaka/polished.fasta`

## Contributing
If you are interested in contributing to nanoporeWorkflow, please take a look at the [contribution guidelines](CONTRIBUTING.md). We welcome issues or pull requests!

## Future plans
  * add flags/options for other sequencing kits, barcoding kits, flowcells (direct RNAseq?)
    * R9.4.1 + rapid or ligation sequencing kit without barcoding (RAD-004)
    * R10 + ligation without barcoding 
    * R10.3 + ligation with & without barcoding
  * Add option for Medaka polishing with r941_min_fast model, if reads were basecalled with the fast Guppy model
  
## Resources
  * https://github.com/fenderglass/Flye
  * https://github.com/isovic/racon
  * https://github.com/nanoporetech/medaka
  * https://github.com/nanoporetech/qcat
  * How to set Guppy parameters (requires Nanopore Community login credentials) https://community.nanoporetech.com/protocols/Guppy-protocol/v/gpb_2003_v1_revl_14dec2018/how-to-configure-guppy-parameters
