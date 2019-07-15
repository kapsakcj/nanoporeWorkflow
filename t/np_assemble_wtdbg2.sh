#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

projectDir=$thisDir/vanilla.project/barcode12

@test "Usage statement" {
  run bash $scriptsDir/np_assemble_wtdbg2.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Files are present" {
  [ -d $projectDir ]
  [ -f "$projectDir/all.fastq.gz" ]
  [ -f "$projectDir/readlengths.txt.gz" ]
}

@test "Assembly with wtdbg2" {

  if [ ! -f "$projectDir/unpolished.fasta" ]; then
    run bash $scriptsDir/np_assemble_wtdbg2.sh $projectDir
    [ "$status" -eq 0 ]
  fi

  RANDOM=42 # set seed
  hashsum=$(grep ">" $projectDir/unpolished.fasta | md5sum | cut -f 1 -d ' ')
  [[   "$hashsum" == "b75ce4e49cf6618077dfab6664d41359" ]] || \
    [[ "$hashsum" == "be4533790362104fa23fd7a85e09e9a4" ]]

  # contig names
  # >ctg1 len=64596
  # >ctg2 len=28015
  # >ctg3 len=16744
  # >ctg4 len=10897
  # OR
  # >ctg1 len=64712
  # >ctg2 len=28005
  # >ctg3 len=16743


}

