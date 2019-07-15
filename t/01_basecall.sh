#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

# Uncompress files
if [ ! -e "$thisDir/data/.uncompressed" ]; then
  tar --directory $thisDir/data -Jxvf $thisDir/data/SalmonellaMontevideo.FAST5.tar.xz && \
    touch $thisDir/data/.uncompressed
fi

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

  [ -d "vanilla.project/barcode12" ]
  [ -d "vanilla.project/unclassified" ]
  [ -e "vanilla.project/barcoding_summary.txt" ]
  [ -e "vanilla.project/sequencing_summary.txt" ]
}

