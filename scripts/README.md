# Individual scripts

Each script represents a single unit or module in the nanopore workflow.
They are designed so that they can be replaced modularly.

| stage             | prefix           | I/O directory     | expected input files        | expected output files |
| ------------------ |------------------ | ------------------- | ----------------------------| --------------------- |
| Basecall/demux   | `basecall-demux` | project-level     | fast5 directory (parameter) | new project directory of subfolders labeled `barcodeXX` where `XX` is an integer pertaining to a sample |
| Prep sample      | `prepSample`     | barcode directory | fastq file(s)               | `all.fastq.gz` containing all fastq entries in one file. `readlengths.txt.gz` which describes lengths of all reads. `reads.minlen1000.600Mb.fastq.gz` which contains highest quality reads amounting to 600 Mb that are >1kb in length |
| Assembly         | `assemble`       | barcode directory | `all.fastq.gz`, `readlengths.txt.gz` | `unpolished.fasta` |
| Assembly | `np_assemble_flye.sh` | barcode directory | `reads.minlen1000.600Mb.fastq.gz` | `flye/assembly.fasta` |
| Polishing        | `polish`         | barcode directory | `unpolished.fasta` and either fastq or fast5 files as a parameter | `polished.fasta` |
| Polishing | `np_consensus_racon.sh` | barcode directory | `flye/assembly.fasta` | `ctg.consensus.iteration4.fasta` |
| Polishing | `np_polishing_medaka.sh` | barcode directory | `racon/ctg.consensus.iteration4.fasta` | `medaka/polished.fasta` |
