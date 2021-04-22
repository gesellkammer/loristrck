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
 *	lorisPartialListOps.i
 *
 *	Auxiliary SWIG interface file describing operations on PartialList objects.
 *  All of these are also implemented as methods of PartialList.
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


/* ***************** inserted C++ code ***************** */

%{
    using Loris::PartialList;
%}

/* ***************** end of inserted C++ code ***************** */

// ----------------------------------------------------------------
//		wrap functions in the procedural interface
//
//	Not all functions in the procedural interface are trivially
//	wrapped, some are wrapped to return newly-allocated objects,
//	which we wouldn't do in the procedural interface, but we
//	can do, because SWIG and the scripting langauges take care of 
//	the memory management ambiguities.
//

%feature("docstring", 
"Label Partials in a PartialList with the integer nearest to the
amplitude-weighted average ratio of their frequency envelope to a
reference frequency envelope. If a reference frequency is specified,
then the reference envelope is constant at that frequency.

The frequency spectrum is partitioned into non-overlapping channels
whose time-varying center frequencies track the reference frequency
envelope. The reference label indicates which channel's center
frequency is exactly equal to the reference envelope frequency, and
other channels' center frequencies are multiples of the reference
envelope frequency divided by the reference label. Each Partial in the
PartialList is labeled with the number of the channel that best fits
its frequency envelope. Partials are labeled, but otherwise
unmodified.

For finer control over channelization, including harmonic stretching
for stiff strings, and amplitude weighting for determining the
best-fitting channel, use the Channelizer class."
) channelize;

void channelize( PartialList * partials, 
                 LinearEnvelope * refFreqEnvelope, int refLabel );

%inline
%{

	void channelize( PartialList * partials, double refFreq )
    {
    	//	create a constant envelope at refFreq
    	LinearEnvelope env( refFreq );    	
		Channelizer::channelize( *partials, env, 1 );
    }
                 
%}
                
%feature("docstring",
"Collate unlabeled (zero-labeled) Partials into the smallest-possible 
number of Partials that does not combine any overlapping Partials.
Collated Partials assigned labels higher than any label in the original 
list, and appear at the end of the sequence, after all previously-labeled
Partials. Optionally specify the fade and gap times, else default values
are used.") collate_duh;

%rename( collate ) collate_duh;

%inline 
%{
    // there seems to be a collision with a symbol name
    // in localefwd.h (GNU) that is somehow getting
    // imported, and using statements do not solve
    // the problem as they should.
    void collate_duh( PartialList * partials, 
				  	  double fadeTime = Collator::DefaultFadeTimeMs/1000.0, 
				  	  double gapTime = Collator::DefaultSilentTimeMs/1000.0 )
    {
    	Collator c( fadeTime, gapTime );
        c.collate( *partials );
    }
%}

%feature("docstring", 
"Dilate Partials in a PartialList according to the given initial
and target time points. Partial envelopes are stretched and
compressed so that temporal features at the initial time points
are aligned with the final time points. Time points are sorted, so
Partial envelopes are are only stretched and compressed, but
breakpoints are not reordered. Duplicate time points are allowed.
There must be the same number of initial and target time points.") dilate;


//	dilate needs a contract to guarantee that the
//	same number of initial and target points are
//	provided.
%contract dilate( PartialList * partials, 
                  const std::vector< double > & ivec, 
                  const std::vector< double > & tvec ) 
{
require:
	ivec->size() == tvec->size();
}

%inline
%{
	void dilate( PartialList * partials, 
		   	     const std::vector< double > & ivec, 
				 const std::vector< double > & tvec )
	{
		const double * initial = &( ivec.front() );
		const double * target = &( tvec.front() );
		int npts = ivec.size();
		dilate( partials, initial, target, npts );
	}
%}

%feature("docstring",
"Distill labeled (channelized) Partials in a PartialList into a 
PartialList containing at most one Partial per label. Unlabeled 
(zero-labeled) Partials are left unmodified at the end of the 
distilled Partials. Optionally specify the fade and gap times, 
defaults are 5ms and 1ms.
") wrap_distill;

%rename( distill ) wrap_distill;

%inline
%{
	void wrap_distill( PartialList * partials, 
				      double fadeTime = Distiller::DefaultFadeTimeMs/1000.0, 
				      double gapTime = Distiller::DefaultSilentTimeMs/1000.0 )
	{
		try
		{
			Distiller d( fadeTime, gapTime );
			d.distill( *partials );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}
%}


%feature("docstring",
"Apply a reference Partial to fix the frequencies of Breakpoints
whose amplitude is below threshold_dB. Threshold 0 harmonifies all
Partials. To apply only to quiet Partials, specify a lower 
threshold (like -90). The reference Partial is the first Partial
in the PartialList labeled refLabel (usually 1). The Envelope,
if specified, is a time-varying weighting on the harmonifing process. 
When 1, harmonic frequencies are used, when 0, breakpoint frequencies are 
unmodified. ") harmonify;

%inline %{
	void harmonify( PartialList * partials, long refLabel,
                    const Envelope * env, double threshold_dB )
	{
		try
		{
			Harmonifier::harmonify( partials->begin(), partials->end(), 
									refLabel, *env, threshold_dB );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}

    void harmonify( PartialList * partials, long refLabel, 
                    double threshold_dB )
    {
        LinearEnvelope e( 1 );
        try
		{
			Harmonifier::harmonify( partials->begin(), partials->end(), 
                                	refLabel, e, threshold_dB );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
    }
%}      

%feature("docstring",
"Resample all Partials in a PartialList using the specified
sampling interval, so that the Breakpoints in the Partial
envelopes will all lie on a common temporal grid. 

The Breakpoint times in resampled Partials will comprise a
contiguous sequence of ALL integer multiples of the sampling interval
(a lot of data, but useful for some third-party tools, like the CNMAT
sinusoids~ external for Max/MSP). 

If a timing envelope is specified, then that envelope represents
a warping of the time axis that is applied during resampling. The
Breakpoint times in resampled Partials will a comprise contiguous 
sequence of all integer multiples of the sampling interval between 
the first and last breakpoints in the timing envelope, and each 
Breakpoint will represent the parameters of the original Partial 
at the time that is the value of the timing envelope at that instant.
This can be used to achieve effects similar to dilation (see dilate),
but can also be used to achieve time-reveral and scrubbing effects.

If phase correct resampling is selected, Partial frequencies are
altered slightly to match, as nearly as possible, the Breakpoint
phases after resampling. Phases are updated so that the Partial
frequencies and phases are consistent after resampling. The
default is phase correct resampling, unless a timing envelope
is specified, in which case it is better to explcitly match
phases at known critical points.

See also quantize, which was previously described as sparse
resampling.")  wrap_resample;

%rename( resample ) wrap_resample;

%inline %{

    void wrap_resample( PartialList * partials, double interval, 
				   		bool denseResampling = true,
				     	bool phaseCorrect = true )
	{
			
		try
		{		
			Resampler r( interval );
			r.setPhaseCorrect( phaseCorrect );
			if ( denseResampling )
			{
                r.resample( *partials );
            }
            else
            {
                r.quantize( *partials );
            }
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}

	void wrap_resample( PartialList * partials, LinearEnvelope * timing, 
	                    double interval,
				     	bool phaseCorrect = false )
	{			
		try
		{		
			Resampler r( interval );
			r.setPhaseCorrect( phaseCorrect );
			r.resample( *partials, *timing );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}
%}


%feature("docstring",
"Quantize the Breakpoint times in the specified Partials.
Each Breakpoint in the Partials is replaced by a Breakpoint
constructed by resampling the Partial at the nearest
integer multiple of the of the resampling interval.

In previous versions of Loris, this was called sparse resampling.
") quantize;
	
%inline %{

	void quantize( PartialList * partials, double interval )
	{
		try
		{		
			Resampler r( interval );
			r.setPhaseCorrect( true );
			r.quantize( *partials );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );
		}
	}

%}

%feature("docstring",
"Eliminate overlapping Partials having the same label
(except zero). If any two partials with same label
overlap in time, keep only the longer of the two.
Set the label of the shorter duration partial to zero.
Optionally specify the fade time, default is 1ms.") fake_sift;

%rename( sift ) fake_sift;

%inline
%{
	void fake_sift( PartialList * partials, 
				    double fadeTime = Sieve::DefaultFadeTimeMs/1000.0 )
	{
		Sieve s( fadeTime );
		s.sift( *partials );
	}
%}


// ----------------------------------------------------------------
//		wrap PartialUtils
//

%feature("docstring",
"Trim Partials by removing Breakpoints outside a specified time span.
Insert a Breakpoint at the boundary when cropping occurs.
") crop;

void crop( PartialList * partials, double t1, double t2 );


%feature("docstring",
"Bad old name for scaleAmplitude.") scaleAmp;

%feature("docstring",
"Scale the amplitude of a Partial, or all Partials in a PartialList, according 
to an envelope representing a time-varying amplitude scale value.")
scaleAmplitude;
				 
%inline 
%{	

	void scaleAmp( PartialList * partials, Envelope * ampEnv )
	{
		PartialUtils::scaleAmplitude( partials->begin(), partials->end(), *ampEnv );
	}
	
	void scaleAmplitude( PartialList * partials, Envelope * ampEnv )
	{
		PartialUtils::scaleAmplitude( partials->begin(), partials->end(), *ampEnv );
	}

    void scaleAmplitude( Partial * p, Envelope * ampEnv )
	{
		PartialUtils::scaleAmplitude( *p, *ampEnv );
	}

    void scaleAmp( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleAmplitude( partials->begin(), partials->end(), e );
	}
	
	void scaleAmplitude( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleAmplitude( partials->begin(), partials->end(), e );
	}
	
	void scaleAmplitude( Partial * p, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleAmplitude( *p, e );
	}
%}

%feature("docstring",
"Scale the bandwidth of a Partial, or all Partials in a PartialList, according 
to an envelope representing a time-varying bandwidth scale value.") scaleBandwidth;

%inline %{	

	void scaleBandwidth( PartialList * partials, Envelope * bwEnv )
	{
		PartialUtils::scaleBandwidth( partials->begin(), partials->end(), *bwEnv );
	}
				 

	void scaleBandwidth( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleBandwidth( partials->begin(), partials->end(), e );
	}
	
	void scaleBandwidth( Partial * p, Envelope * bwEnv )
	{
		PartialUtils::scaleBandwidth( *p, *bwEnv );
	}
				 

	void scaleBandwidth( Partial * p, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleBandwidth( *p, e );
	}	
%}

%feature("docstring",
"Scale the frequency of a Partial, or all Partials in a PartialList, according 
to an envelope representing a time-varying frequency scale value.") scaleFrequency;
				 
%inline %{	

	void scaleFrequency( PartialList * partials, Envelope * freqEnv )
	{
		PartialUtils::scaleFrequency( partials->begin(), partials->end(), *freqEnv );
	}

	void scaleFrequency( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleFrequency( partials->begin(), partials->end(), e );
	}
	
	void scaleFrequency( Partial * p, Envelope * freqEnv )
	{
		PartialUtils::scaleFrequency( *p, *freqEnv );
	}

	void scaleFrequency( Partial * p, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleFrequency( *p, e );
	}
	
%}

%feature("docstring",
"Scale the relative noise content of a Partial, or all Partials in a PartialList,
according to an envelope representing a (time-varying) noise energy 
scale value.") scaleNoiseRatio;


%inline 
%{	

	void scaleNoiseRatio( PartialList * partials, Envelope * noiseEnv )
	{
		PartialUtils::scaleNoiseRatio( partials->begin(), partials->end(), *noiseEnv );
	}

	void scaleNoiseRatio( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleNoiseRatio( partials->begin(), partials->end(), e );
	}
	
	void scaleNoiseRatio( Partial * p, Envelope * noiseEnv )
	{
		PartialUtils::scaleNoiseRatio( *p, *noiseEnv );
	}

	void scaleNoiseRatio( Partial * p, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::scaleNoiseRatio( *p, e );
	}
%}

%feature("docstring",
"Set the bandwidth of a Partial, or all Partials in a PartialList, according 
to an envelope representing a time-varying bandwidth value.") setBandwidth;

%inline 
%{	

	void setBandwidth( PartialList * partials, Envelope * bwEnv )
	{
		PartialUtils::setBandwidth( partials->begin(), partials->end(), *bwEnv );
	}
	
	void setBandwidth( PartialList * partials, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::setBandwidth( partials->begin(), partials->end(), e );
	}
	
	void setBandwidth( Partial * p, Envelope * bwEnv )
	{
		PartialUtils::setBandwidth( *p, *bwEnv );
	}
	
	void setBandwidth( Partial * p, double val )
	{
		LinearEnvelope e( val );
		PartialUtils::setBandwidth( *p, e );
	}
%}
