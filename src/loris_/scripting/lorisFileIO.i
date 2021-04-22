/*
 * This is the Loris C++ Class Library, implementing analysis, 
 * manipulation, and synthesis of digitized sounds using the Reassigned 
 * Bandwidth-Enhanced Additive Sound Model.
 *
 * Loris is Copyright (c) 1999-2016 by Kelly Fitz and Lippold Haken
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY, without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *
 *	lorisFileIO.i
 *
 *	Auxiliary SWIG interface file describing file I/O operations and classes.
 *  Includes import and export functions from the procedural interface, file 
 *  classes AiffFile, SdifFile, and SpcFile, and the Marker class used to mark
 *  and identify features in imported and exported samples and Partials.
 * 
 *	Include this file in loris.i to include these classes and functions 
 *  in the scripting module. This interface file does not stand on its own.
 *
 * Kelly Fitz, 6 Dec 2013
 * loris@cerlsoundgroup.org
 *
 * http://www.cerlsoundgroup.org/Loris/
 *
 */


// ----------------------------------------------------------------
//		wrap I/O functions from the procedural interface
// ---------------------------------------------------------------------------
//
//	Not all functions in the procedural interface are trivially
//	wrapped, some are wrapped to return newly-allocated objects,
//	which we wouldn't do in the procedural interface, but we
//	can do, because SWIG and the scripting langauges take care of 
//	the memory management ambiguities.
//

%feature("docstring",
"Export audio samples stored in a vector to an AIFF file having the
specified number of channels and sample rate at the given file
path (or name). The floating point samples in the vector are
clamped to the range (-1.,1.) and converted to integers having
bitsPerSamp bits. The default values for the sample rate and
sample size, if unspecified, are 44100 Hz (CD quality) and 16 bits
per sample, respectively. If neither is specified, then the 
default synthesis parameters (see SynthesisParameters) are used.

If a PartialList is specified, the Partials are rendered at the
specified sample rate and then exported.

Only mono files can be exported, the last argument is ignored, 
and is included only for backward compatability") wrap_exportAiff;

%rename( exportAiff ) wrap_exportAiff;

// Need this junk, because SWIG changed the way it handles
// default arguments when writing C++ wrappers.
//
%inline 
%{
	void wrap_exportAiff( const char * path, const std::vector< double > & samples,
					      double samplerate = 44100, int bitsPerSamp = 16, 
					      int nchansignored = 1 )
	{
		exportAiff( path, &(samples.front()), samples.size(), 
					samplerate, bitsPerSamp );
	}
	
	void wrap_exportAiff( const char * path, PartialList * partials,
					      double samplerate = 44100, int bitsPerSamp = 16 )
	{
		try
		{
			std::vector< double > vec;
			
			Synthesizer synth( samplerate, vec );			
			synth.synthesize( partials->begin(), partials->end() );
		
			exportAiff( path, &(vec.front()), vec.size(), 
					    samplerate, bitsPerSamp );
					
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}
	
%}

%feature("docstring",
"Export Partials in a PartialList to a SDIF file at the specified
file path (or name). SDIF data is written in the Loris RBEP
format. For more information about SDIF, see the SDIF website at:
	www.ircam.fr/equipes/analyse-synthese/sdif/  ") exportSdif;

void exportSdif( const char * path, PartialList * partials );

%feature("docstring",
"Export Partials in a PartialList to a Spc file at the specified
file path (or name). The fractional MIDI pitch must be specified.
The optional enhanced parameter defaults to true (for
bandwidth-enhanced spc files), but an be specified false for
pure-sines spc files. The optional endApproachTime parameter is in
seconds; its default value is zero (and has no effect). A nonzero
endApproachTime indicates that the PartialList does not include a
release, but rather ends in a static spectrum corresponding to the
final breakpoint values of the partials. The endApproachTime
specifies how long before the end of the sound the amplitude,
frequency, and bandwidth values are to be modified to make a
gradual transition to the static spectrum.");

void exportSpc( const char * path, PartialList * partials, double midiPitch, 
				int enhanced, double endApproachTime );

// Need these two also, because SWIG changed the way it handles
// default arguments when writing C++ wrappers.
//
%inline %{
void exportSpc( const char * path, PartialList * partials, double midiPitch,
			    int enhanced )
{
	exportSpc( path, partials, midiPitch, enhanced, 0. );
}
%}
%inline %{
void exportSpc( const char * path, PartialList * partials, double midiPitch )
{
	exportSpc( path, partials, midiPitch, true, 0. );
}
%}
                  

%feature("docstring",
"Import Partials from an SDIF file at the given file path (or
name), and return them in a PartialList. Loris can import
SDIF data stored in 1TRC format or in the Loris RBEP format.
For more information about SDIF, see the SDIF website at:
	www.ircam.fr/equipes/analyse-synthese/sdif/");
	
%newobject importSdif;
%inline %{
	PartialList * importSdif( const char * path )
	{
		PartialList * dst = createPartialList();
		importSdif( path, dst );

		// check for exception:
		if (check_exception())
		{
			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
%}


%feature("docstring",
"Import Partials from an Spc file at the given file path (or
name), and return them in a PartialList.");

%newobject importSpc;
%inline %{
	PartialList * importSpc( const char * path )
	{
		PartialList * dst = createPartialList();
		importSpc( path, dst );

		// check for exception:
		if (check_exception())
		{
			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
%}


// ---------------------------------------------------------------------------
//		wrap Loris file I/O classes
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
//	class AiffFile
//	
%feature("docstring",
"An AiffFile represents a sample file (on disk) in the Audio Interchange
File Format. The file is read from disk and the samples stored in memory
upon construction of an AiffFile instance. The samples are accessed by 
the samples() method, which converts them to double precision floats and
returns them in a vector.") AiffFile;

%newobject AiffFile::samples;

%feature("docstring",
"");

class AiffFile
{
public:
%feature("docstring",
"An AiffFile instance can be initialized in any of the following ways:

Initialize a new AiffFile from a vector of samples and sample rate.

Initialize a new AiffFile from two vectors of samples, for left and right
channels, and sample rate.

Initialize a new AiffFile using data read from a named file.

Initialize an instance of AiffFile having the specified sample 
rate, accumulating samples rendered at that sample rate from
all Partials in the specified PartialList with the (optionally) 
specified Partial fade time (see Synthesizer.h for an explanation 
of fade time). 
") AiffFile;

	AiffFile( const char * filename );
	AiffFile( const std::vector< double > & vec, double samplerate );
    AiffFile( const std::vector< double > & vec_left,
              const std::vector< double > & vec_right, 
              double samplerate );    

	%extend 
	{

		AiffFile( PartialList * l, double sampleRate = 44100, double fadeTime = .001 ) 
		{
			return new AiffFile( l->begin(), l->end(), sampleRate, fadeTime );
		}
	}
	
%feature("docstring",
"Destroy this AiffFile.") ~AiffFile;

	~AiffFile( void );
	
%feature("docstring",
"Return the sample rate in Hz for this AiffFile.") sampleRate;

	double sampleRate( void ) const;
	
%feature("docstring",
"Return the MIDI note number for this AiffFile. The defaul
note number is 60, corresponding to middle C.") midiNoteNumber;
	
	double midiNoteNumber( void ) const;

	//	this has been renamed
%feature("docstring",
"Return the number of sample frames (equal to the number of samples
in a single channel file) stored by this AiffFile.") numFrames;

	%rename( sampleFrames ) numFrames;
	unsigned long numFrames( void ) const;
		
%feature("docstring",
"Render the specified Partial using the (optionally) specified
Partial fade time, and accumulate the resulting samples into
the sample vector for this AiffFile.") addPartial;

	void addPartial( const Partial & p, double fadeTime = .001 /* 1 ms */ );

%feature("docstring",
"Set the fractional MIDI note number assigned to this AiffFile. 
If the sound has no definable pitch, use note number 60.0 
(the default).") setMidiNoteNumber;

	void setMidiNoteNumber( double nn );
		 
%feature("docstring",
"Export the sample data represented by this AiffFile to
the file having the specified filename or path. Export
signed integer samples of the specified size, in bits
(8, 16, 24, or 32).") write;

void write( const char * filename, unsigned int bps = 16 );
	
	%extend 
	{
	
%feature("docstring",
"Return a copy of the samples (as floating point numbers
on the range -1,1) stored in this AiffFile.") samples; 

		std::vector< double > samples( void )
		{
			return self->samples();
		}

		 
%feature("docstring",
"The number of channels is always 1. 
Loris only deals in mono AiffFiles") channels;

		int channels( void ) { return 1; }

%feature("docstring",
"Render all Partials on the specified half-open (STL-style) range
with the (optionally) specified Partial fade time (see Synthesizer.h
for an examplanation of fade time), and accumulate the resulting 
samples.") addPartials;

		void addPartials( PartialList * l, double fadeTime = 0.001/* 1ms */ )
		{
			self->addPartials( l->begin(), l->end(), fadeTime );
		}
		
%feature("docstring",
"Return the (possibly empty) collection of Markers for 
this AiffFile.") markers;

		std::vector< Marker > markers( void )
		{
			return self->markers();
		}

%feature("docstring",
"Append a collection of Markers for to the existing
set of Markers for this AiffFile.") addMarkers;

		void addMarkers( const std::vector< Marker > & markers )
		{
			self->markers().insert( self->markers().end(),
			                        markers.begin(), markers.end() );
		}
	
%feature("docstring",
"Specify a new (possibly empty) collection of Markers for
this AiffFile.") setMarkers;

		void setMarkers( const std::vector< Marker > & markers )
		{
			self->markers().assign( markers.begin(), markers.end() );
		}
	}
};

// ---------------------------------------------------------------------------
//	class SdifFile
//
%feature("docstring",
"Class SdifFile represents reassigned bandwidth-enhanced Partial 
data in a SDIF-format data file. Construction of an SdifFile 
from a stream or filename automatically imports the Partial
data.") SdifFile;


%newobject SdifFile::partials;

class SdifFile
{
public:
 %feature("docstring",
"Initialize an instance of SdifFile by importing Partial data from
the file having the specified filename or path, 
or initialize an instance of SdifFile storing the Partials in
the specified PartialList. If no PartialList is specified,
construct an empty SdifFile.") SdifFile;

	SdifFile( const char * filename );
	SdifFile( void );
	 
%feature("docstring",
"Destroy this SdifFile.") ~SdifFile;

	 ~SdifFile( void );
		
%feature("docstring",
"Export the Partials represented by this SdifFile to
the file having the specified filename or path.") write; 

	void write( const char * path );

%feature("docstring",
"Export the envelope Partials represented by this SdifFile to
the file having the specified filename or path in the 1TRC
format, resampled, and without phase or bandwidth information.") write1TRC;

	void write1TRC( const char * path );
	
	%extend 
	{
		SdifFile( PartialList * l ) 
		{
			return new SdifFile( l->begin(), l->end() );
		}
	
%feature("docstring",
"Return a copy of the Partials represented by this SdifFile.") partials;

		PartialList * partials( void )
		{
			PartialList * plist = new PartialList( self->partials() );
			return plist;
		}
		 
%feature("docstring",
"Add all the Partials in a PartialList to this SdifFile.") addPartials;

		void addPartials( PartialList * l )
		{
			self->addPartials( l->begin(), l->end() );
		}
		 
		//	add members to access Markers
		// 	now much improved to take advantage of 
		// 	SWIG support for std::vector.
%feature("docstring",
"Return the (possibly empty) collection of Markers for 
this SdifFile.") markers;

		std::vector< Marker > markers( void )
		{
			return self->markers();
		}

%feature("docstring",
"Append a collection of Markers for to the existing
set of Markers for this SdifFile.") addMarkers;

		void addMarkers( const std::vector< Marker > & markers )
		{
			self->markers().insert( self->markers().end(),
			                        markers.begin(), markers.end() );
		}
	
%feature("docstring",
"Specify a new (possibly empty) collection of Markers for
this SdifFile.") setMarkers;

		void setMarkers( const std::vector< Marker > & markers )
		{
			self->markers().assign( markers.begin(), markers.end() );
		}	
	}	
		 
};	//	end of class SdifFile

// ---------------------------------------------------------------------------
//	class SpcFile
//
%feature("docstring",
"Class SpcFile represents a collection of reassigned bandwidth-enhanced
Partial data in a SPC-format envelope stream data file, used by the
real-time bandwidth-enhanced additive synthesizer implemented on the
Symbolic Sound Kyma Sound Design Workstation. Class SpcFile manages 
file I/O and conversion between Partials and envelope parameter streams.") SpcFile;

%newobject SpcFile::partials;

class SpcFile
{
public:
%feature("docstring",
"Construct and return a new SpcFile by importing envelope parameter 
streams from the file having the specified filename or path, 
or initialize an instance of SpcFile having the specified fractional
MIDI note number. If a PartialList is specified, add those
Partials to the file. Otherwise, the new SpcFile contains 
no Partials (or envelope parameter streams).
The default MIDI note number is 60 (middle C).") SpcFile;

	SpcFile( const char * filename );
	SpcFile( double midiNoteNum = 60 );

%feature("docstring",
"Destroy this SpcFile.") ~SpcFile;
   
	~SpcFile( void );
	
%feature("docstring",
"Return the sample rate for this SpcFile in Hz.") sampleRate;

	double sampleRate( void ) const;

%feature("docstring",
"Return the MIDI note number for this SpcFile.
Note number 60 corresponds to middle C.") sampleRate;

	double midiNoteNumber( void ) const;

%feature("docstring",
"Add the specified Partial to the enevelope parameter streams
represented by this SpcFile. If a label is specified, use that
label, instead of the Partial's label, for the Partial added to
the SpcFile.

A SpcFile can contain only one Partial having any given (non-zero) 
label, so an added Partial will replace a Partial having the 
same label, if such a Partial exists.

This may throw an InvalidArgument exception if an attempt is made
to add unlabeled Partials, or Partials labeled higher than the
allowable maximum.   
") addPartial;

	void addPartial( const Partial & p );
	void addPartial( const Partial & p, int label );

%feature("docstring",
"Set the fractional MIDI note number assigned to this SpcFile. 
If the sound has no definable pitch, use note number 60.0 (the default).") setMidiNoteNumber;

	void setMidiNoteNumber( double nn );
	 
%feature("docstring",
"Set the sampling freqency in Hz for the spc data in this
SpcFile. This is the rate at which Kyma must be running to ensure
proper playback of bandwidth-enhanced Spc data.
The default sample rate is 44100 Hz.") setSampleRate;

	void setSampleRate( double rate );
			 
%feature("docstring",
"Export the envelope parameter streams represented by this SpcFile to
the file having the specified filename or path. Export phase-correct 
bandwidth-enhanced envelope parameter streams if enhanced is true 
(the default), or pure sinsoidal streams otherwise.

A nonzero endApproachTime indicates that the Partials do not include a
release or decay, but rather end in a static spectrum corresponding to the
final Breakpoint values of the partials. The endApproachTime specifies how
long before the end of the sound the amplitude, frequency, and bandwidth
values are to be modified to make a gradual transition to the static spectrum.

If the endApproachTime is not specified, it is assumed to be zero, 
corresponding to Partials that decay or release normally.") write;

	void write( const char * filename, bool enhanced = true,
				double endApproachTime = 0 );

	
	%extend 
	{
		SpcFile( PartialList * l, double midiNoteNum = 60 ) 
		{
			return new SpcFile( l->begin(), l->end(), midiNoteNum );
		}
	
%feature("docstring",
"Return a copy of the Partials represented by this SdifFile.") partials;

		PartialList * partials( void )
		{
			PartialList * plist = new PartialList( self->partials().begin(), self->partials().end() );
			return plist;
		}

%feature("docstring",
"Add all the Partials in a PartialList to this SpcFile.
			
A SpcFile can contain only one Partial having any given (non-zero) 
label, so an added Partial will replace a Partial having the 
same label, if such a Partial exists.

This may throw an InvalidArgument exception if an attempt is made
to add unlabeled Partials, or Partials labeled higher than the
allowable maximum.") addPartials;

		void addPartials( PartialList * l )
		{
			self->addPartials( l->begin(), l->end() );
		}
		 
%feature("docstring",
"Return the (possibly empty) collection of Markers for 
this SpcFile.") markers;

		std::vector< Marker > markers( void )
		{
			return self->markers();
		}

%feature("docstring",
"Append a collection of Markers for to the existing
set of Markers for this SpcFile.") addMarkers;

		void addMarkers( const std::vector< Marker > & markers )
		{
			self->markers().insert( self->markers().end(),
			                        markers.begin(), markers.end() );
		}
	
%feature("docstring",
"Specify a new (possibly empty) collection of Markers for
this SpcFile.") setMarkers;

		void setMarkers( const std::vector< Marker > & markers )
		{
			self->markers().assign( markers.begin(), markers.end() );
		}
	}
	
};	//	end of class SpcFile


// ---------------------------------------------------------------------------
//	class Marker
//
%feature("docstring",
"Class Marker represents a labeled time point in a set of Partials
or a vector of samples. Collections of Markers (see the MarkerContainer
definition below) are held by the File I/O classes in Loris (AiffFile,
SdifFile, and SpcFile) to identify temporal features in imported
and exported data.") Marker;

class Marker
{
public:
//	-- construction --
	
%feature("docstring",
"Initialize a Marker with the specified time (in seconds) and name,
or copy the time and name from another Marker. If unspecified, time 
is zero and the label is empty.") Marker;

	Marker( void );
	 
	Marker( double t, const char * s );	 

	Marker( const Marker & other );
	
%feature("docstring",
"Destroy this Marker.") Marker::~Marker;
	~Marker( void );

		 
//	-- access --

%feature("docstring",
"Return the name of this Marker.");

	%extend 
	{
		const char * name( void ) { return self->name().c_str(); }
	}
	 
%feature("docstring",
"Return the time (in seconds) associated with this Marker.");

	double time( void );
	 
//	-- mutation --

%feature("docstring",
"Set the name of the Marker.");

	void setName( const char * s );
	 
%feature("docstring",
"Set the time (in seconds) associated with this Marker.");

	void setTime( double t );

	
};	//	end of class Marker

