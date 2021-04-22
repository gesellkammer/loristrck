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
 *	lorisAnalyzer.i
 *
 *	Auxiliary SWIG interface file describing the Loris Analyzer class.
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

// ---------------------------------------------------------------------------
//	class Analyzer
//	

%feature("docstring",
"An Analyzer represents a configuration of parameters for
performing Reassigned Bandwidth-Enhanced Additive Analysis
of sampled waveforms. This analysis process yields a collection 
of Partials, each having a trio of synchronous, non-uniformly-
sampled breakpoint envelopes representing the time-varying 
frequency, amplitude, and noisiness of a single bandwidth-
enhanced sinusoid. 

For more information about Reassigned Bandwidth-Enhanced 
Analysis and the Reassigned Bandwidth-Enhanced Additive Sound 
Model, refer to the Loris website: 

	http://www.cerlsoundgroup.org/Loris/
") Analyzer;


%newobject Analyzer::analyze;
			
class Analyzer
{
public:
%feature("docstring",
"Construct and return a new Analyzer configured with the given	
frequency resolution (minimum instantaneous frequency	
difference between Partials) and analysis window main 
lobe width (between zeros). All other Analyzer parameters 	
are computed from the specified resolution and window
width. If the window width is not specified, 
then it is set to twice the resolution. If an envelope is
provided for the frequency resolution, then it describes
the time-varying analysis resolution in Hz. 

An Analyzer configuration can also be copied from another
instance.") Analyzer;
	 
	Analyzer( double resolutionHz );
	Analyzer( double resolutionHz, double windowWidthHz );
	Analyzer( const Envelope & resolutionEnv, double windowWidthHz );	
	Analyzer( const Analyzer & another );

%feature("docstring",
"Destroy this Analyzer.") ~Analyzer;

	~Analyzer( void );
		
	%extend 
	{
%feature("docstring",
"Analyze a vector of (mono) samples at the given sample rate 	  	
(in Hz) and return the resulting Partials in a PartialList.
If specified, use a frequency envelope as a fundamental reference for
Partial formation.") analyze;

		PartialList analyze( const std::vector< double > & vec, double srate )
		{
			PartialList partials;
			if ( ! vec.empty() )
			{
				partials = self->analyze( vec, srate );
			}
			return partials;
		}
		 
		PartialList analyze( const std::vector< double > & vec, double srate, 
                             Envelope * env )
		{
			PartialList partials;
			if ( ! vec.empty() )
			{
				partials = self->analyze( vec, srate, *env );
			}
			return partials;
		}
	}
	
%feature("docstring",
"Return the amplitude floor (lowest detected spectral amplitude),              
in (negative) dB, for this Analyzer.");

	double ampFloor( void ) const;


%feature("docstring",
"Return the crop time (maximum temporal displacement of a time-
frequency data point from the time-domain center of the analysis
window, beyond which data points are considered \"unreliable\")
for this Analyzer.");

 	double cropTime( void ) const;

%feature("docstring",
"Return the maximum allowable frequency difference between                     
consecutive Breakpoints in a Partial envelope for this Analyzer.");

 	double freqDrift( void ) const;

%feature("docstring",
"Return the frequency floor (minimum instantaneous Partial                  
frequency), in Hz, for this Analyzer.");

 	double freqFloor( void ) const;

%feature("docstring",
"Return the frequency resolution (minimum instantaneous frequency          
difference between Partials) for this Analyzer at the specified
time in seconds. If no time is specified, then the initial resolution
(at 0 seconds) is returned.");

	double freqResolution( double time = 0.0 ) const;

%feature("docstring",
"Return the hop time (which corresponds approximately to the 
average density of Partial envelope Breakpoint data) for this 
Analyzer.");

	double hopTime( void ) const;

%feature("docstring",
"Return the sidelobe attenutation level for the Kaiser analysis window in
positive dB. Higher numbers (e.g. 90) give very good sidelobe 
rejection but cause the window to be longer in time. Smaller 
numbers raise the level of the sidelobes, increasing the likelihood
of frequency-domain interference, but allow the window to be shorter
in time.");

  	double sidelobeLevel( void ) const;

%feature("docstring",
"Return the frequency-domain main lobe width (measured between 
zero-crossings) of the analysis window used by this Analyzer.");

	double windowWidth( void ) const;

%feature("docstring",
"Return true if the phases and frequencies of the constructed
 partials should be modified to be consistent at the end of the
 analysis, and false otherwise. (Default is true.)");
 
    bool phaseCorrect( void ) const;
    
	
%feature("docstring",
"Set the amplitude floor (lowest detected spectral amplitude), in              
(negative) dB, for this Analyzer.");

	void setAmpFloor( double x );
	
%feature("docstring",
"Deprecated, use storeResidueBandwidth instead.");

 	void setBwRegionWidth( double x );
	
%feature("docstring",
"Set the crop time (maximum temporal displacement of a time-
frequency data point from the time-domain center of the analysis
window, beyond which data points are considered \"unreliable\")
for this Analyzer.");

 	void setCropTime( double x );
	
%feature("docstring",
"Set the maximum allowable frequency difference between                     
consecutive Breakpoints in a Partial envelope for this Analyzer.");

	void setFreqDrift( double x );
	
%feature("docstring",
"Set the amplitude floor (minimum instantaneous Partial                  
frequency), in Hz, for this Analyzer.");

	void setFreqFloor( double x );
	
%feature("docstring",
"Set the frequency resolution (minimum instantaneous frequency          
difference between Partials) for this Analyzer. (Does not cause     
other parameters to be recomputed.)");

	void setFreqResolution( double x );
	void setFreqResolution( const Envelope & e );  
	
%feature("docstring",
"Set the hop time (which corresponds approximately to the average
density of Partial envelope Breakpoint data) for this Analyzer.");

 	void setHopTime( double x );
	
%feature("docstring",
"Set the sidelobe attenutation level for the Kaiser analysis window in
positive dB. Larger numbers (e.g. 90) give very good sidelobe 
rejection but cause the window to be longer in time. Smaller 
numbers raise the level of the sidelobes, increasing the likelihood
of frequency-domain interference, but allow the window to be shorter
in time.");

	void setSidelobeLevel( double x );
	
%feature("docstring",
"Set the frequency-domain main lobe width (measured between 
zero-crossings) of the analysis window used by this Analyzer.");

	void setWindowWidth( double x );
	
%feature("docstring",
"Indicate whether the phases and frequencies of the constructed
 partials should be modified to be consistent at the end of the
 analysis. (Default is true.)");

    void setPhaseCorrect( bool TF = true );
    
    
%feature("docstring",
"Construct Partial bandwidth envelopes during analysis
by associating residual energy in the spectrum (after
peak extraction) with the selected spectral peaks that
are used to construct Partials. 

regionWidth is the width (in Hz) of the bandwidth 
association regions used by this process, must be positive.
If unspecified, a default value is used.");

	void storeResidueBandwidth( double regionWidth = Analyzer::Default_ResidueBandwidth_RegionWidth );
	
%feature("docstring",
"Construct Partial bandwidth envelopes during analysis
by storing the mixed derivative of short-time phase, 
scaled and shifted so that a value of 0 corresponds
to a pure sinusoid, and a value of 1 corresponds to a
bandwidth-enhanced sinusoid with maximal energy spread
(minimum sinusoidal convergence).

tolerance is the amount of range over which the 
mixed derivative indicator should be allowed to drift away 
from a pure sinusoid before saturating. This range is mapped
to bandwidth values on the range [0,1]. Must be positive and 
not greater than 1. If unspecified, a default value is used.");
	
%feature("compactdefaultargs") storeConvergenceBandwidth;
	
	void storeConvergenceBandwidth( double tolerance = 0.01 * Analyzer::Default_ConvergenceBandwidth_TolerancePct );

%feature("docstring",
"Disable bandwidth envelope construction. Bandwidth 
will be zero for all Breakpoints in all Partials.");
	
	void storeNoBandwidth( void );

%feature("docstring",
"Return true if this Analyzer is configured to compute
bandwidth envelopes using the spectral residue after
peaks have been identified, and false otherwise.");

	bool bandwidthIsResidue( void ) const;

%feature("docstring",
"Return true if this Analyzer is configured to compute
bandwidth envelopes using the mixed derivative convergence
indicator, and false otherwise.");

	bool bandwidthIsConvergence( void ) const;

%feature("docstring",
"Return the width (in Hz) of the Bandwidth Association regions
used by this Analyzer, only if the spectral residue method is
used to compute bandwidth envelopes. Return zero if the mixed
derivative method is used, or if no bandwidth is computed.");

	double bwRegionWidth( void ) const;

%feature("docstring",
"Return the mixed derivative convergence tolerance
only if the convergence indicator is used to compute
bandwidth envelopes. Return zero if the spectral residue
method is used or if no bandwidth is computed.");

	double bwConvergenceTolerance( void ) const;


%feature("docstring",
"Return the fundamental frequency estimate envelope constructed
during the most recent analysis performed by this Analyzer.
Will be empty unless buildFundamentalEnv was invoked to enable the
construction of this envelope during analysis.") fundamentalEnv;

    LinearEnvelope fundamentalEnv( void ) const;
        
%feature("docstring",
"Configure the fundamental frequency estimator.

fmin is the lower bound on the fundamental frequency estimate.
fmax is the upper bound on the fundamental frequency estimate
threshDb is the lower bound on the amplitude of a spectral peak
that will constribute to the fundamental frequency estimate (very
low amplitude peaks tend to have less reliable frequency estimates).
Default is -60 dB.
threshHz is the upper bound on the frequency of a spectral
peak that will constribute to the fundamental frequency estimate.
Default is 8 kHz.

The fundamental frequency estimate can be accessed by
fundamentalEnv() after the analysis is complete.
") buildFundamentalEnv;


    void buildFundamentalEnv( double fmin, double fmax, 
                              double threshDb = -60, double threshHz = 8000 );

%feature("docstring",
"Return the overall amplitude estimate envelope constructed
during the most recent analysis performed by this Analyzer.") ampEnv;

    LinearEnvelope ampEnv( void ) const;
    
%feature("docstring",
"Legacy support, do not use. The amplitude and frequency envelopes
are always estimated.") buildAmpEnv;

    void buildAmpEnv( bool TF = true );

    void buildFundamentalEnv( bool TF = true );

};	//	end of class Analyzer


