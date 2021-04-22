#!python
#
#   This is the Loris C++ Class Library, implementing analysis, 
#   manipulation, and synthesis of digitized sounds using the Reassigned 
#   Bandwidth-Enhanced Additive Sound Model.
#   
#   Loris is Copyright (c) 1999-2016 by Kelly Fitz and Lippold Haken
#  
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#  
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY, without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   GNU General Public License for more details.
#  
#   You should have received a copy of the GNU General Public License
#   along with this program (Loris); if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA,
#	or to the authors at loris@cerlsoundgroup.org.
#  
#  
#	morphdemo.py
#
#	Loris instrument tone morphing demonstration.
#
#   Kelly Fitz, 28 Sept 1999
#   loris@cerlsoundgroup.org
#  
#   http://www.cerlsoundgroup.org/Loris/
#
#	updated 10 March 2009 for Loris 1.5.3 by Kelly Fitz
#  
"""
Welcome to the Loris morphing demo!
Kelly Fitz 2009

Generates several morphs between a clarinet, 
a flute, and a cello.

In order to run this demo, the Loris module must be 
in your PYTHONPATH.
"""
print __doc__

import loris, os, time
print '(in %s)\n' % os.getcwd()

print '(using Loris version %s)\n' % loris.version()

srcdir = 'source'

#
#	analyze flute tone
#
# The analysis process is as follows:
# - configure the analyzer (the flute and clarinet use the
# same analyzer configuration)
# - analyze, yielding a collection of partials
# - construct a constant reference envelope and distill partials
# (this reduces the number of partials considerably by 
# connecting and condensing related partials; for example, 
# in quasi-harmonic sounds, the distillation process yields
# one partial per harmonic)
# - a test synthesis of the distilled partials is performed,
# just as a sanity check, and to verify the suitability of the
# analysis configuration and distillation parameters
#
print 'analyzing flute 3D (%s)' % time.ctime(time.time())
a = loris.Analyzer(.8*291, 1.0*291)
ff = loris.AiffFile( os.path.join(srcdir, 'flute.source.aiff') )
v = ff.samples()
samplerate = ff.sampleRate()
flut = a.analyze( v, samplerate )
print 'using 291 Hz as reference frequency for channelization'
flut_ref = loris.LinearEnvelope( 291 )
loris.channelize( flut, flut_ref, 1 )
loris.distill( flut )

#
#	analyze clarinet tone
#
print 'analyzing clarinet 3G# (%s)' % time.ctime(time.time())
a = loris.Analyzer(.8*415, 1.0*415)
cf = loris.AiffFile( os.path.join(srcdir, 'clarinet.source.aiff') )
v = cf.samples()
samplerate = cf.sampleRate()
clar = a.analyze( v, samplerate )
print 'using estimated fundamental as reference'
env = a.fundamentalEnv()
loris.channelize( clar, env, 1 )
loris.distill( clar )
print 'shifting clarinet pitch down by six half steps'
loris.shiftPitch( clar, loris.LinearEnvelope( -600 ) )
print 'doubling amplitude'
loris.scaleAmp( clar, loris.LinearEnvelope( 2 ) )

#
#	analyze cello tone
#
print 'analyzing cello 2D# (%s)' % time.ctime(time.time())
a = loris.Analyzer(.7*135, 1.8*135)
celf = loris.AiffFile( os.path.join(srcdir, 'cello.source.aiff') )
v = celf.samples()
samplerate = celf.sampleRate()
cel = a.analyze( v, samplerate )
print 'estimate fundamental from partials as reference'
est = loris.FundamentalFromPartials()
tspan = loris.timeSpan( cel )
cel_ref = est.buildEnvelope( cel, tspan[0], tspan[1], 0.01, 100, 200, 0.95 ) 
loris.channelize( cel, cel_ref, 1 )
loris.distill( cel )

#
#	perform temporal dilation
#
# Times are the beginning and end times 
# of the attack and the release. To change 
# the duration of the morph, change the 
# target times (tgt_times), as well as the
# morphing function, mf, defined below.
# 
flute_times = [0.175, 0.4, 2.15, 2.31]
clar_times = [0., 0.185, 1.9, 2.15]
cel_times = [0., 0.13, 2.55, 3.9]
tgt_times = [0., 0.19, 3., 3.25]

print 'dilating sounds to match', tgt_times, '(%s)' % time.ctime(time.time())
print 'flute times:', flute_times
loris.dilate( flut, flute_times, tgt_times )
print 'clarinet times:', clar_times
loris.dilate( clar, clar_times, tgt_times )
print 'cello times:', cel_times
loris.dilate( cel, cel_times, tgt_times )

#
#	synthesize and save dilated sources
#
# Save the synthesized samples files, and SDIF files
# for each dilated source.
#
fname = 'flute.dilated.aiff'
print 'synthesizing', fname, '(%s)' % time.ctime(time.time())
loris.exportAiff( fname, loris.synthesize( flut, samplerate ), samplerate, 16 )
fname = 'flute.dilated.sdif'
print 'exporting sdif file:', fname, '(%s)' % time.ctime(time.time())
loris.exportSdif( fname, flut )

fname = 'clar.dilated.aiff'
print 'synthesizing', fname, '(%s)' % time.ctime(time.time())
loris.exportAiff( fname, loris.synthesize( clar, samplerate ), samplerate, 16 )
fname = 'clarinet.dilated.sdif'
print 'exporting sdif file:', fname, '(%s)' % time.ctime(time.time())
loris.exportSdif( fname, clar )

fname = 'cello.dilated.aiff'
print 'synthesizing', fname, '(%s)' % time.ctime(time.time())
loris.exportAiff( fname, loris.synthesize( cel, samplerate ), samplerate, 16 )
fname = 'cello.dilated.sdif'
print 'exporting sdif file:', fname, '(%s)' % time.ctime(time.time())
loris.exportSdif( fname, cel )


#
#	perform morphs
#
# Morphs are from the first sound to the 
# second over the time 0.6 to 1.6 seconds.
#
mf = loris.LinearEnvelope()
mf.insertBreakpoint( 0.6, 0 )
mf.insertBreakpoint( 1.6, 1 )

samplerate = 44100.

print 'morphing flute and clarinet (%s)' % time.ctime(time.time())
m = loris.morph( clar, flut, mf, mf, mf )
# render samples, and export to AIFF
samps = loris.synthesize( m, samplerate )
loris.exportAiff( 'clariflute.aiff', samps,
				  samplerate, 16 )
				  
print 'exporting sdif file clariflute.aiff', '(%s)' % time.ctime(time.time())
loris.exportSdif( 'clariflute.sdif', m )
	  
# morph and render samples	  
m = loris.morph( flut, clar, mf, mf, mf )
fout = loris.AiffFile( m, samplerate )
fout.write( 'flutinet.aiff' )


print 'morphing flute and cello (%s)' % time.ctime(time.time())
print 'shifting flute pitch down by eleven half steps'
flut_low = flut.copy()
loris.shiftPitch( flut_low, loris.LinearEnvelope( -1100 ) )

m = loris.morph( cel, flut_low, mf, mf, mf )
fout = loris.AiffFile( m, samplerate )
fout.write( 'cellute.aiff' )

m = loris.morph( flut_low, cel, mf, mf, mf )
fout = loris.AiffFile( m, samplerate )
fout.write( 'flutello.aiff' )


print 'morphing flute and cello again (%s)' % time.ctime(time.time())
print 'shifting flute pitch up by one half step'
loris.shiftPitch( flut, loris.LinearEnvelope( 100 ) )

# double all labels:
for p in flut:
	p.setLabel( p.label() * 2 )
	

print 'exporting Spc files for pre-morphed flute and cello sounds.'
print '(Spc files can be used to drive oscillator banks in Kyma)'

print 'exporting Spc file flute.premorph.spc', '(%s)' % time.ctime(time.time())
loris.exportSpc('flute.premorph.spc', flut, 62, 0)
print 'exporting Spc file cello.premorph.spc', '(%s)' % time.ctime(time.time())
loris.exportSpc('cello.premorph.spc', cel, 50, 0)

m = loris.morph( cel, flut, mf, mf, mf )
fout = loris.AiffFile( m, samplerate )
fout.write( 'cellute2.aiff' )


print 'exporting Spc file for second flute and cello morph.'
print 'exporting Spc file cellute2.spc', '(%s)' % time.ctime(time.time())
loris.exportSpc('cellute2.spc', m, 50, 0)

m = loris.morph( flut, cel, mf, mf, mf )
fout = loris.AiffFile( m, samplerate )
fout.write( 'flutello2.aiff' )



# all done
print 'hey, I\'m spent. (%s)' % time.ctime(time.time())

