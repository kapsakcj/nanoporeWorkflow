# nanoporeWorkflow

## scripts

This is a collection of scripts that do one thing at a time.  For example, demultiplexing or basecalling.

## workflows

This is a collection of workflows in the form of shell scripts.  They qsub the scripts individually.
The first positional parameter must be the project folder.  Both input and output go to the project folder.
