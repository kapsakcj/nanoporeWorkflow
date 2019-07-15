#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

@test "Usage statement" {
  run bash $scriptsDir/01_basecall.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Base calling and demultiplexing with guppy" {
  if [ ! -e $thisDir/vanilla.project ]; then
    run bash $scriptsDir/01_basecall.sh $thisDir/vanilla.project $thisDir/data/SalmonellaMontevideo.FAST5
    [ "$status" -eq 0 ] # usage exits with 0
  fi

  [ -d "$thisDir/vanilla.project/barcode12" ]
  [ -d "$thisDir/vanilla.project/unclassified" ]
  [ -e "$thisDir/vanilla.project/barcoding_summary.txt" ]
  [ -e "$thisDir/vanilla.project/sequencing_summary.txt" ]
}

