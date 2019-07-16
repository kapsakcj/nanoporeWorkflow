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

  export RANDOM=42
  if [ ! -f "$projectDir/polished.fasta" ]; then
    run bash $scriptsDir/np_polish_medaka.sh $projectDir
    [ "$status" -eq 0 ]
  fi

  # The test will be whether the stochastic assembly matches ours enough
  blastn -query $projectDir/polished.fasta -db $thisDir/data/polished.fasta -outfmt 6 > $projectDir/polished.blast.tsv

  sort -k1,2 -k3,3nr $projectDir/polished.blast.tsv |\
    perl -lane '
      $F[0] = substr($F[0],0,4);
      next if($F[0] ne $F[1]);

      $score{$F[0]} += $F[11];

      END{
        for my $contig(sort keys(%score)){
          print join("\t", $contig, $score{$contig});
        }
      }
    ' > $projectDir/polished.scores.tsv

  score1=$(grep ctg1 $projectDir/polished.scores.tsv | cut -f 2)
  [ "$score1" -gt 100000 ]
  score2=$(grep ctg2 $projectDir/polished.scores.tsv | cut -f 2)
  [ "$score2" -gt 40000  ]
  score3=$(grep ctg3 $projectDir/polished.scores.tsv | cut -f 2)
  [ "$score3" -gt 20000  ]

}

