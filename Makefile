#!/usr/bin/env make

# Manual makefile
# Major targets are: install, test, clean

.DELETE_ON_ERROR:

.default: install

install: t/.data-uncompress.done

# Make all large files depend on git-lfs
t/data/.git-lfs.done:
	git lfs pull origin
	touch $@

# Uncompress large file(s)
t/.data-uncompress.done: t/data/.git-lfs.done t/data/SalmonellaMontevideo.FAST5.tar.xz
	tar --directory t/data -Jxvf t/data/SalmonellaMontevideo.FAST5.tar.xz
	touch $@

# Wrapper for cleaning all the things
clean: clean-large-files clean-tests

# Clean only the large files
clean-large-files:
	rm -vf t/data/SalmonellaMontevideo.FAST5.tar.xz
	rm -rvf t/data/SalmonellaMontevideo.FAST5
	rm -vf t/.data-uncompress.done
	rm -vf t/data/.git-lfs.done

# Clean test results
clean-tests:
	rm t/*.done
	rm -rvf t/vanilla.project

# For any test, run it with bats and then touch the file
t/%.done:
	exe=t/$$(basename $@ .done) && \
		echo bats $$exe &&\
		bats $$exe
	touch $@

test: t/np_basecall-demux_guppy.sh t/np_prepSample_readLengths.sh t/np_assemble_wtdbg2.sh t/np_polish_nanopolish.sh

