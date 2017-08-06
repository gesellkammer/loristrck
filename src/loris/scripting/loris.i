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
 *	loris.i
 *
 *  SWIG interface file for building scripting language modules
 *  implementing Loris functionality.
 *
 * Kelly Fitz, 8 Nov 2000
 * rewrite: Kelly Fitz, 23 Jan 2003
 * loris@cerlsoundgroup.org
 *
 * http://www.cerlsoundgroup.org/Loris/
 *
 */

%include exception.i 
%include typemaps.i 
%include std_vector.i
%include std_list.i

// ----------------------------------------------------------------
//		docstring for the Loris module (Python)
//
%define DOCSTRING
"
Loris is an Open Source sound modeling and processing software package
based on the Reassigned Bandwidth-Enhanced Additive Sound Model. Loris
supports modified resynthesis and manipulations of the model data,
such as time- and frequency-scale modification and sound morphing.


Loris is developed by Kelly Fitz and Lippold Haken at the CERL Sound
Group, and is distributed under the GNU General Public License (GPL).
For more information, please visit

   http://www.cerlsoundgroup.org/Loris/
"
%enddef

%module(docstring=DOCSTRING) loris

// enable automatic docstring generation in Python module
%feature("autodoc","0");

// ----------------------------------------------------------------
//		include Loris headers needed to generate wrappers
//
%{
	#include "loris.h"
	
	#include "AiffFile.h"
	#include "Analyzer.h"
	#include "Channelizer.h"
	#include "Collator.h"
	#include "Distiller.h"
	#include "Harmonifier.h"
	#include "LorisExceptions.h"
	#include "LinearEnvelope.h"
	#include "Marker.h"
	#include "Partial.h"
	#include "PartialUtils.h"
    #include "Resampler.h"
	#include "SdifFile.h"
	#include "Sieve.h"
	#include "SpcFile.h"
	#include "Synthesizer.h"

	//	import the entire Loris namespace
	using namespace Loris;
	
	#include <stdexcept>
	#include <vector>
%}

// ----------------------------------------------------------------
//		Use the SWIG library to wrap std::vectors.
//
namespace std {
   %template(DoubleVector) vector< double >;
   %template(MarkerVector) vector< Marker >;
};

// ----------------------------------------------------------------
//		notification and exception handlers
//
//	Exception handling code for procedural interface calls.
//	Copied from the SWIG manual. Tastes great, less filling.

%{ 
	static char error_message[256];
	static int error_status = 0;
	
	void throw_exception( const char *msg ) 
	{
		strncpy(error_message,msg,256);
		error_status = 1;
	}
	
	void clear_exception( void ) 
	{
		error_status = 0;
	}
	
	char *check_exception( void ) 
	{
		if ( error_status ) 
		{
			return error_message;
		}
		else 
		{
			return NULL;
		}
	}
%}

//	Wrap all calls into the Loris library with exception
//	handlers to prevent exceptions from leaking out of the
//	C++ code, wherein they can be handled, and into the
//	interpreter, where they will surely cause an immediate
//	halt. Only std::exceptions and Loris::Exceptions (and 
//	subclasses) can be thrown.
//
//	This is a unified exception handler -- handles both 
//  C++ exceptions and errors raised in the procedural 
//  interface, through the exception handling mechanism 
//  defined above (copied from the SWIG manual).
//
//	These should probably not all report UnknownError, could
//	make an effort to raise the right kind of (SWIG) exception.
//
%exception {
	try
	{	
	    char * err;
	    clear_exception();
		$action
		if ( 0 != (err = check_exception()) )
        {
            Throw( Loris::Exception, err );
        }
	}
	catch( Loris::Exception & ex ) 
	{
		//	catch Loris::Exceptions:
		std::string s("Loris exception: " );
		s.append( ex.what() );
		SWIG_exception( SWIG_UnknownError, (char *) s.c_str() );
	}
	catch( std::exception & ex ) 
	{
		//	catch std::exceptions:
		std::string s("std C++ exception: " );
		s.append( ex.what() );
		SWIG_exception( SWIG_UnknownError, (char *) s.c_str() );
	}
}

//	Configure notification and debugging using a
//	in a SWIG initialization block. This code is
//	executed when the module is loaded by the 
//	host interpreter.
//
%{
	//	notification function for Loris debugging
	//	and notifications, installed in initialization
	//	block below:
	static void printf_notifier( const char * s )
	{
		printf("*\t%s\n", s);
	}	
%}

%init 
%{
    // configure Loris procedural interface notification 
    // and exception handling
	setNotifier( printf_notifier );
	setExceptionHandler( throw_exception );
%}

// ----------------------------------------------------------------
//		wrap procedural interface
//
//	Not all functions in the procedural interface are trivially
//	wrapped, some are wrapped to return newly-allocated objects,
//	which we wouldn't do in the procedural interface, but we
//	can do, because SWIG and the scripting langauges take care of 
//	the memory management ambiguities.
//



%feature("docstring",
"Return a newly-constructed LinearEnvelope using the legacy 
FrequencyReference class. The envelope will have approximately
the specified number of samples. The specified number of samples 
must be greater than 1. Uses the FundamentalEstimator 
(FundamentalFromPartials) class to construct an estimator of 
fundamental frequency, configured to emulate the behavior of
the FrequencyReference class in Loris 1.4-1.5.2. If numSamps
is unspecified, construct the reference envelope from fundamental 
estimates taken every five milliseconds.

For simple sounds, this frequency reference may be a 
good first approximation to a reference envelope for
channelization (see channelize()).") createFreqReference;

%newobject createFreqReference;
LinearEnvelope * 
createFreqReference( PartialList * partials, 
					 double minFreq, double maxFreq, long numSamps );

// why can't I use default arguments to do this?
// Because SWIG wants all default arguments to be
// match the C++ function declaration with it is
// processing C++ code. 
%inline 
%{
	LinearEnvelope * 
	createFreqReference( PartialList * partials, 
						 double minFreq, double maxFreq )
	{
		return createFreqReference( partials, minFreq, maxFreq, 0 );
	}
%}

%feature("docstring",
"Return a newly-constructed LinearEnvelope that estimates
the time-varying fundamental frequency of the sound
represented by the Partials in a PartialList. This uses
the FundamentalEstimator (FundamentalFromPartials) 
class to construct an estimator of fundamental frequency, 
and returns a LinearEnvelope that samples the estimator at the 
specified time interval (in seconds). Default values are used 
to configure the estimator. Only estimates in the specified 
frequency range will be considered valid, estimates outside this 
range will be ignored.") createF0Estimate;
   
%newobject createF0Estimate;   
LinearEnvelope * 
createF0Estimate( PartialList * partials, double minFreq, double maxFreq, 
                  double interval );



%feature("docstring",
"Copy Partials in the source PartialList having the specified label
into a new PartialList. The source PartialList is unmodified.
") copyLabeled;

%newobject copyLabeled;
%inline %{
	PartialList * copyLabeled( PartialList * partials, long label )
	{
		PartialList * dst = createPartialList();
		copyLabeled( partials, label, dst );
		
		// check for exception:
		if ( check_exception() )
		{
			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
%}

%feature("docstring",
"Extract Partials in the source PartialList having the specified
label and return them in a new PartialList.") extractLabeled;

%newobject extractLabeled;
%inline %{
	PartialList * extractLabeled( PartialList * partials, long label )
	{
		PartialList * dst = createPartialList();
		extractLabeled( partials, label, dst );
		
		// check for exception:
		if ( check_exception() )
		{
			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
%}

%feature("docstring",
"Remove from a PartialList all Partials having the specified label.") removeLabeled;

void removeLabeled( PartialList * partials, long label );



%feature("docstring",
"Scale the amplitudes of a set of Partials by applying 
a spectral suface constructed from another set.
If frequency and time stretch factors are specified,
then the spectral surface is stretched by those 
factors before the surface is used to shape the 
Partial amplitudes.");

void shapeSpectrum( PartialList * partials, PartialList * surface,
                    double stretchFreq, double stretchTime );

%inline %{	
	void shapeSpectrum( PartialList * partials, PartialList * surface )
	{
		shapeSpectrum( partials, surface, 1.0, 1.0 );
	}
%}	          

%feature("docstring",
"Shift the pitch of all Partials in a PartialList according to 
the given pitch envelope. The pitch envelope is assumed to have 
units of cents (1/100 of a halfstep).");


%inline 
%{	
	void shiftPitch( PartialList * partials, Envelope * pitchEnv )
	{
		PartialUtils::shiftPitch( partials->begin(), partials->end(), *pitchEnv );	
	}
	
	void shiftPitch( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::shiftPitch( partials->begin(), partials->end(), e );
	}
	
%}

%feature("docstring",
"Shift the time of all the Breakpoints in a Partial by a constant
amount (in seconds).");

void shiftTime( PartialList * partials, double offset );



%feature("docstring",
"Sort the Partials in a PartialList in order of increasing label.
The sort is stable; Partials having the same label are not
reordered.");

void sortByLabel( PartialList * partials );

%feature("docstring",
"Return the average amplitude over all Breakpoints in this Partial.
Return zero if the Partial has no Breakpoints.") avgAmplitude;

double avgAmplitude( const Partial * p );

%feature("docstring",
"Return the average frequency over all Breakpoints in this Partial.
Return zero if the Partial has no Breakpoints.") avgFrequency;

double avgFrequency( const Partial * p );

%feature("docstring",
"Return the maximum amplitude achieved by a Partial.") peakAmplitude;

double peakAmplitude( const Partial * p );

%feature("docstring",
"Return the minimum start time and maximum end time
of all Partials in this PartialList.") timeSpan;

%apply double * OUTPUT { double * tmin_out, double * tmax_out };
void timeSpan( PartialList * partials, double * tmin_out, double * tmax_out );

%feature("docstring",
"Return the average frequency over all Breakpoints in this Partial, 
weighted by the Breakpoint amplitudes. Return zero if the Partial 
has no Breakpoints.") weightedAvgFrequency;

double weightedAvgFrequency( const Partial * p );

%feature("docstring",
"Recompute phases of all Breakpoints later than the specified 
time so that the synthesized phases of those later Breakpoints 
matches the stored phase, as long as the synthesized phase at 
the specified time matches the stored (not recomputed) phase.

Phase fixing is only applied to non-null (nonzero-amplitude) 
Breakpoints, because null Breakpoints are interpreted as phase 
reset points in Loris. If a null is encountered, its phase is 
corrected from its non-Null successor, if it has one, otherwise 
it is unmodified.") fixPhaseAfter;

void fixPhaseAfter( PartialList * partials, double time );

%feature("docstring",
"Recompute phases of all Breakpoints in a Partial
so that the synthesized phases match the stored phases, 
and the synthesized phase at (nearest) the specified
time matches the stored (not recomputed) phase.

Backward phase-fixing stops if a null (zero-amplitude) 
Breakpoint is encountered, because nulls are interpreted as 
phase reset points in Loris. If a null is encountered, the 
remainder of the Partial (the front part) is fixed in the 
forward direction, beginning at the start of the Partial. 
Forward phase fixing is only applied to non-null 
(nonzero-amplitude) Breakpoints. If a null is encountered, 
its phase is corrected from its non-Null successor, if 
it has one, otherwise it is unmodified.") fixPhaseAt;

void fixPhaseAt( PartialList * partials, double time );

%feature("docstring",
"Recompute phases of all Breakpoints earlier than the specified 
time so that the synthesized phases of those earlier Breakpoints 
matches the stored phase, and the synthesized phase at the 
specified time matches the stored (not recomputed) phase.

Backward phase-fixing stops if a null (zero-amplitude) Breakpoint
is encountered, because nulls are interpreted as phase reset 
points in Loris. If a null is encountered, the remainder of the 
Partial (the front part) is fixed in the forward direction, 
beginning at the start of the Partial.") fixPhaseBefore;

void fixPhaseBefore( PartialList * partials, double time );

%feature("docstring",
"Fix the phase travel between two times by adjusting the
frequency and phase of Breakpoints between those two times.

This algorithm assumes that there is nothing interesting 
about the phases of the intervening Breakpoints, and modifies 
their frequencies as little as possible to achieve the correct 
amount of phase travel such that the frequencies and phases at 
the specified times match the stored values. The phases of all 
the Breakpoints between the specified times are recomputed.") fixPhaseBetween;

void fixPhaseBetween( PartialList * partials, double tbeg, double tend );

%feature("docstring",
"Recompute phases of all Breakpoints later than the specified 
time so that the synthesized phases of those later Breakpoints 
matches the stored phase, as long as the synthesized phase at 
the specified time matches the stored (not recomputed) phase. 
Breakpoints later than tend are unmodified.

Phase fixing is only applied to non-null (nonzero-amplitude) 
Breakpoints, because null Breakpoints are interpreted as phase 
reset points in Loris. If a null is encountered, its phase is 
corrected from its non-Null successor, if it has one, otherwise 
it is unmodified.") fixPhaseForward;

void fixPhaseForward( PartialList * partials, double tbeg, double tend );

/*
%feature("docstring",
"Adjust frequencies of the Breakpoints in the 
 specified Partial such that the rendered Partial 
achieves (or matches as nearly as possible, within 
the constraint of the maximum allowable frequency
alteration) the analyzed phases. 

partial The Partial whose frequencies,
and possibly phases (if the frequencies
cannot be sufficiently altered to match
the phases), will be recomputed.

maxFixPct The maximum allowable frequency 
alteration, default is 0.2%.") fixFrequency;

void fixFrequency( Partial & partial, double maxFixPct = 0.2 );
*/

%feature("docstring",
"Return a string describing the Loris version number.");

%inline %{
	const char * version( void )
	{
		static const char * vstr = LORIS_VERSION_STR;
		return vstr;
	}
%}
 



// ----------------------------------------------------------------
//	Include auxiliary SWIG interface files.

%include lorisPartialList.i

%include lorisFundamental.i

%include lorisEnvelope.i

%include lorisSynthesizer.i

%include lorisChannelizer.i

%include lorisPartialListOps.i

%include lorisMorph.i

%include lorisFileIO.i

%include lorisAnalyzer.i