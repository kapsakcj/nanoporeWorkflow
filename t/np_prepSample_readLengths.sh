#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

projectDir=$thisDir/vanilla.project/barcode12

@test "Usage statement" {
  run bash $scriptsDir/np_prepSample_readLengths.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Preparing barcode12 folder" {
  run gunzip $projectDir/*.fastq.gz # get back to fastq files just to help reset things

  [ -d $projectDir ]
  [ $(find $projectDir -maxdepth 1 -type f -name '*.fastq' | wc -l) -gt 0 ]
  [ -e "$projectDir/sequencing_summary.txt" ]

  run bash $scriptsDir/np_prepSample_readLengths.sh $projectDir
  [ "$status" -eq 0 ]
  [ -f "$projectDir/all.fastq.gz" ]
  [ -f "$projectDir/readlengths.txt.gz" ]
  [ -e "$projectDir/sequencing_summary.txt" ]
}

