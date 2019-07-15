#!/usr/bin/env make

# Manual makefile

.DELETE_ON_ERROR:

.default: install

install: t/data/SalmonellaMontevideo.FAST5.tar.xz

# Make all large files depend on git-lfs
t/data/.git-lfs-finished:
	git lfs pull origin
	touch $@

# The source data file for all tests
t/data/SalmonellaMontevideo.FAST5.tar.xz: t/data/.git-lfs-finished
	tar --directory t/data -Jxvf $@
	# truncate the file to free up space, but also leave it compatible with the xz format
	echo -n "" | xz -c > $@ 

# Wrapper for cleaning all the things
clean: clean-large-files clean-tests

# Clean only the large files
clean-large-files:
	rm -vf t/data/SalmonellaMontevideo.FAST5.tar.xz
	rm -rvf t/data/SalmonellaMontevideo.FAST5
	rm t/data/.git-lfs-finished

# Clean test results
clean-tests:
	rm t/*.done
	rm -rvf t/vanilla.project

# For any test, run it with bats and then touch the file
t/%.done:
	exe=t/$$(basename $@ .done) && \
		bats $$exe
	touch $@

test: t/01_basecall.sh.done t/03_prepSample.sh.done t/05_assemble.sh.done t/07_nanopolish.sh.done

