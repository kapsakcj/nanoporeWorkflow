#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")
export NSLOTS=2 # slots given to us by travis

projectDir=$thisDir/vanilla.project.bak/barcode12

@test "Usage statement" {
  run bash $scriptsDir/07_nanopolish.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Files are present" {
  [ -f "$projectDir/unpolished.fasta" ]
}

@test "polishing with nanopolish" {

  if [ ! -f "$projectDir/polished.fasta" ]; then
    run bash $scriptsDir/07_nanopolish.sh $projectDir $thisDir/data/SalmonellaMontevideo.FAST5
    [ "$status" -eq 0 ]
  fi

  hashsum=$(md5sum vanilla.project.bak/barcode12/polished.fasta | cut -f 1 -d ' ')
  [ "$hashsum" == "c9f56cb11b5e6234a5322a01acf21ae8" ]
}

