"""Loris sound modeling API for Python.

	Loris is an open source C++ class library implementing analysis,
	manipulation, and synthesis of digitized sounds using the Reassigned
	Bandwidth-Enhanced Additive Sound Model.
	
	For more information about Loris and the Reassigned Bandwidth-Enhanced
	Additive Model, contact the developers at loris@cersloundgroup.org, or
	visit them at http://www.cerlsoundgroup.org/Loris/.
	
	The primary distribution point for Loris is SourceForge
	(http://loris.sourceforge.net) and its mirrors.

	Loris is Copyright (c) 1999-2016 by Kelly Fitz and Lippold Haken
"""
import loris

# ---- functions from the Loris procedural interface ----
def channelize( partials, refFreqEnvelope, refLabel ):	
	"""
	Label Partials in a PartialList with the integer nearest to
	the amplitude-weighted average ratio of their frequency envelope
	to a reference frequency envelope. The frequency spectrum is 
	partitioned into non-overlapping channels whose time-varying 
	center frequencies track the reference frequency envelope. 
	The reference label indicates which channel's center frequency
	is exactly equal to the reference envelope frequency, and other
	channels' center frequencies are multiples of the reference 
	envelope frequency divided by the reference label. Each Partial 
	in the PartialList is labeled with the number of the channel
	that best fits its frequency envelope. The quality of the fit
	is evaluated at the breakpoints in the Partial envelope and
	weighted by the amplitude at each breakpoint, so that high-
	amplitude breakpoints contribute more to the channel decision.
	Partials are labeled, but otherwise unmodified. In particular, 
	their frequencies are not modified in any way.
 	"""
 	loris.channelize( partials, refFreqEnvelope, refLabel )
 	
def createFreqReference( partials, minFreq, maxFreq, numSamps = 0 ):
	"""
	Return a newly-constructed BreakpointEnvelope by sampling the 
	frequency envelope of the longest Partial in a PartialList. 
	Only Partials whose frequency at the Partial's loudest (highest 
	amplitude) breakpoint is within the given frequency range are 
	considered. 
	
	If the number of sample points is not specified, then the
	longest Partial's frequency envelope is sampled every 30 ms
	(No fewer than 10 samples are used, so the sampling maybe more
	dense for very short Partials.) 
	
	For very simple sounds, this frequency reference may be a 
	good first approximation to a reference envelope for
	channelization (see channelize()).
 	"""
 	return loris.createFreqReference( partials, minFreq, maxFreq, numSamps )
 	
 # ---- Loris classes ----
class SpcFile:
	"""
	Class SpcFile represents a collection of reassigned 
	bandwidth-enhanced Partial data in a SPC-format envelope 
	stream data file, used by the real-time bandwidth-enhanced 
	additive synthesizer implemented on the Symbolic Sound Kyma 
	Sound Design Workstation. Class SpcFile manages file I/O 
	and conversion between Partials and envelope parameter streams.
	
	Create an SpcFile from a PartialList and a MIDI note 
	number. If unspecified (no argument given), the
	default value of 60 (corresonding to middle C) is used.
		f = SpcFile( partials, 69 ) # A above middle C, 440 Hz

	Create an empty (no Partials) SpcFile by specifying only a
	MIDI note number. If unspecified (no argument given), the
	default value of 60 (corresonding to middle C) is used.
		f = SpcFile( 69 ) # A above middle C, 440 Hz
		
	Import Loris Partials stored in Spc format by constructing
	an SpcFile from a filename, as in
		f = SpcFile( 'mysound.spc' )
		
	"""
	def __init__( self, args ):
		"""
		Initialize a new SpcFile instance.
		"""
		self.imp = loris.SpcFile(args)
		
	def sampleRate( self ):
		"""
		Return the sample rate at which Kyma will render
		this Spc file at the correct pitch.
		"""
		return self.imp.sampleRate()
		
	def midiNoteNumber( self ):
		"""
		Return the MIDI note number at which this Spc file
		is played at the original pitch. Note number 60
		corresponds to middle C.
		"""
		return self.imp.midiNoteNumber()

	def addPartial( self, p ):
		"""
		Add the specified Partial to the enevelope parameter streams
		represented by this SpcFile. 
		
		A SpcFile can contain only one Partial having any given (non-zero) 
		label, so an added Partial will replace a Partial having the 
		same label, if such a Partial exists.

		This may throw an exception if an attempt is made
		to add unlabeled Partials, or Partials labeled higher than the
		allowable maximum.
	 	"""
	 	self.imp.addPartial( p )
	 	
	def addPartial( self, p, label ):
		"""
		Add a Partial, assigning it the specified label (and position in the
		Spc data).
		
		A SpcFile can contain only one Partial having any given (non-zero) 
		label, so an added Partial will replace a Partial having the 
		same label, if such a Partial exists.

		This may throw an InvalidArgument exception if an attempt is made
		to add unlabeled Partials, or Partials labeled higher than the
		allowable maximum.
	 	"""
	 	self.imp.addPartial( p, label )

	def setMidiNoteNumber( self, nn ):
		"""
		Set the fractional MIDI note number assigned to this SpcFile. 
		If the sound has no definable pitch, use note number 60.0 
		(the default).
	 	"""
	 	self.imp.setMidiNoteNumber( nn )
	 
	def setSampleRate( self, rate ):
		"""
		Set the sampling freqency in Hz for the spc data in this
		SpcFile. This is the rate at which Kyma must be running to ensure
		proper playback of bandwidth-enhanced Spc data.
		
		The default sample rate is 44100 Hz.
		"""
		self.imp.setSampleRate( rate )
			 
	def write( self, filename, enhanced = 1, endApproachTime = 0 ):
		"""
		Export the envelope parameter streams represented by this 
		SpcFile to the file having the specified filename or path. 
		Export phase-correct bandwidth-enhanced envelope parameter 
		streams if enhanced is true (the default), or pure sinsoidal 
		streams otherwise.
	
		A nonzero endApproachTime indicates that the Partials do 
		not include a release or decay, but rather end in a static 
		spectrum corresponding to the final Breakpoint values of 
		the partials. The endApproachTime specifies how long before 
		the end of the sound the amplitude, frequency, and bandwidth
		values are to be modified to make a gradual transition to 
		the static spectrum.
		
		If the endApproachTime is not specified, it is assumed to 
		be zero, corresponding to Partials that decay or release 
		normally.
		"""
		self.imp.write( filename, enhanced, endApproachTime )
	
	def partials( self ):
		"""
		Return a copy of the Partials represented by this SpcFile.
		"""
		return self.imp.partials()

	def addPartials( self, partials ):
		"""
		
		Add all Partials in the specified PartialList
		to the enevelope parameter streams represented by this SpcFile. 
		
		A SpcFile can contain only one Partial having any given (non-zero) 
		label, so an added Partial will replace a Partial having the 
		same label, if such a Partial exists.

		This may throw an exception if an attempt is made
		to add unlabeled Partials, or Partials labeled higher than the
		allowable maximum.
		"""
		self.imp.addPartials( partials )
		 
	def numMarkers( self ):
		"""
		Return the number of Markers in this SpcFile.
		"""
		return self.imp.numMarkers()
	
	def getMarker( self, n ):
		"""
		Return the nth Marker in this SpcFile (Markers
		are numbered in the order they are stored in
		the SpcFile on disk starting with 0).  
		An exception is raised if n is greater than or
		equal to the number of Markers in the SpcFile,
		or if it is less than 0.
		"""
		return self.imp.getMarker( n )
		
	def removeMarker( self, n ):
		"""
		Rempve the nth Marker from this SpcFile (Markers
		are numbered in the order they are stored in
		the SpcFile on disk starting with 0).  
		An exception is raised if n is greater than or
		equal to the number of Markers in the SpcFile,
		or if it is less than 0.
		"""
		self.imp.removeMarker( n )
	
	def addMarker( self, marker ):
		"""
		Append a copy of the specified Marker to this
		SpcFile.
		"""
		self.imp.addMarker( marker )
