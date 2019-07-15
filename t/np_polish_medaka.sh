#!/usr/bin/env bats

# BATS https://github.com/sstephenson/bats

load environment
thisDir=$BATS_TEST_DIRNAME
scriptsDir=$(realpath "$thisDir/../scripts")

projectDir=$thisDir/vanilla.project/barcode12

@test "Usage statement" {
  run bash $scriptsDir/np_polish_medaka.sh
  [ "$status" -eq 1 ] # usage exits with 1
  [ "$output" != "" ]
  [ ${output:0:6} == "Usage:" ] # First five characters of the usage statement is "Usage: "
}

@test "Files are present" {
  [ -f "$projectDir/unpolished.fasta" ]
}

@test "polishing with medaka" {

  if [ ! -f "$projectDir/polished.fasta" ]; then
    run bash $scriptsDir/np_polish_medaka.sh $projectDir
    [ "$status" -eq 0 ]
  fi

  hashsum=$(grep ">" $projectDir/polished.fasta | md5sum | cut -f 1 -d ' ')
  [[   "$hashsum" == "67017b71e8f18cd56b15d9970c2cf620" ]] || \
    [[ "$hashsum" == "8dba7783ba37625541ef7cb92c083bb0" ]]

  # >ctg1:7.0-64712.0
  # >ctg2:1.0-27968.0
  # >ctg3:40.0-16743.0

  # >ctg1
  # >ctg2
  # >ctg3
  # >ctg4
}

