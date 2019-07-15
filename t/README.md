# Unit testing

This folder contains unit tests. Tests are wrapped using `bats`.
Before running unit tests, please edit `environment.bash`.  Also,
run `make git-lfs`.

To run any of the tests, run `bats test.sh`.  Or, to run all tests,
`for i in t/*.sh; do bats $i; done;`.

## 01_basecall.sh

## 03_prepSample.sh

## 05_assemble.sh

## 07_nanopolish.sh

