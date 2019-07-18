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
    export RANDOM=42 # set seed
    run bash $scriptsDir/np_assemble_wtdbg2.sh $projectDir
    [ "$status" -eq 0 ]
  fi

  # The test will be whether the stochastic assembly matches ours enough
  blastn -query $projectDir/unpolished.fasta -db $thisDir/data/polished.fasta -outfmt 6 > $projectDir/unpolished.blast.tsv

  sort -k1,2 -k3,3nr $projectDir/unpolished.blast.tsv |\
    perl -lane '
      next if($F[0] ne $F[1]);

      $score{$F[0]} += $F[11];

      END{
        for my $contig(sort keys(%score)){
          print join("\t", $contig, $score{$contig});
        }
      }
    ' > $projectDir/unpolished.scores.tsv

  score1=$(grep ctg1 $projectDir/unpolished.scores.tsv | cut -f 2)
  [ "$score1" -gt 90000 ]
  score2=$(grep ctg2 $projectDir/unpolished.scores.tsv | cut -f 2)
  [ "$score2" -gt 40000  ]
  score3=$(grep ctg3 $projectDir/unpolished.scores.tsv | cut -f 2)
  [ "$score3" -gt 20000  ]

}

