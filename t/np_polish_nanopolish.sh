#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

projectDir=$thisDir/vanilla.project/barcode12

@test "Usage statement" {
  run bash $scriptsDir/np_polish_nanopolish.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Files are present" {
  [ -f "$projectDir/unpolished.fasta" ]
}

@test "polishing with nanopolish" {

  if [ ! -f "$projectDir/polished.fasta" ]; then
    run bash $scriptsDir/np_polish_nanopolish.sh $projectDir $thisDir/data/SalmonellaMontevideo.FAST5
    [ "$status" -eq 0 ]
  fi

  hashsum=$(grep ">" vanilla.project.bak/barcode12/polished.fasta | md5sum | cut -f 1 -d ' ')
  [ "$hashsum" == "67017b71e8f18cd56b15d9970c2cf620" ]
}

