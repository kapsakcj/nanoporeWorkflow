#!/usr/bin/env make

# Manual makefile

.DELETE_ON_ERROR:

.default: install

install: git-lfs

# Make all large file depend on the target git-lfs
git-lfs:
	git lfs pull origin

t/data/SalmonellaMontevideo.FAST5.tar.xz: git-lfs
