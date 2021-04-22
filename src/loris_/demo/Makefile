# Loris is Copyright (c) 1999-2016 by Kelly Fitz and Lippold Haken
# <loris@cerlsoundgroup.org>
#  
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without 
# modifications, as long as this notice is preserved.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

demo_sources = source/flute.source.aiff source/clarinet.source.aiff source/cello.source.aiff
demo_script = morphdemo.py

demo_tarball = loris-demo-1.5.3.tgz

demo_output = cello.dilated.aiff \
	cello.dilated.sdif \
	cello.premorph.spc \
	cellute.aiff \
	cellute2.aiff \
	cellute2.spc \
	clar.dilated.aiff \
	clariflute.aiff \
	clariflute.sdif \
	clarinet.dilated.sdif \
	flute.dilated.aiff \
	flute.dilated.sdif \
	flute.premorph.spc \
	flutello.aiff \
	flutello2.aiff \
	flutinet.aiff

scriptingdir = ../scripting

env_run = env PYTHONPATH=$(scriptingdir):$(scriptingdir)/.libs python $(demo_script)
noenv_run = python $(demo_script)

GACK = "!!! cannot run the demos script without the sound sources !!!"


# targets:

all: demo

demo:
	-test -f $(demo_source_tarball) && tar zxf $(demo_source_tarball)
	(test -f "source/clarinet.source.aiff" && \
	test -f "source/cello.source.aiff" && \
	test -f "source/flute.source.aiff" ) || \
	(echo $(GACK) && return 1)
	( test -d $(scriptingdir)  \
	&& echo "using Loris distribution" \
	&& $(env_run) ) || \
	$(noenv_run)

	
	
$(demo_tarball): Makefile README $(demo_script)
	tar cvf $(demo_tarball) Makefile README $(demo_script) $(demo_sources)
	
	
dist: $(demo_tarball)	

clean:
	rm -f $(demo_output)
	
distclean: clean
	-rm $(demo_tarball)
