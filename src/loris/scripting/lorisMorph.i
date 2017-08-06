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
 *	lorisMorph.i
 *
 *	Auxiliary SWIG interface file describing morphing operations.
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

%{
#include "Morpher.h"

//	Assign these flags initially the default values used by the Morpher class.
static bool DoLogAmplitudeMorphing = Morpher::DefaultDoLogAmplitudeMorphing;
static bool DoLogFrequencyMorphing = Morpher::DefaultDoLogFrequencyMorphing;

%}

%feature("docstring",
"Enable or disable log-domain amplitude and bandwidth morphing.") enableLogAmpMorphing;

%feature("docstring",
"Enable or disable log-domain frequency morphing.") enableLogFreqMorphing;


%inline %{

	void enableLogAmpMorphing( bool enableFlag )
	{
		DoLogAmplitudeMorphing = enableFlag;
	}
	
	void enableLogFreqMorphing( bool enableFlag )
	{
		DoLogFrequencyMorphing = enableFlag;
	}	
	
%}


%feature("docstring",
"Morph labeled Partials in two PartialLists according to the
given frequency, amplitude, and bandwidth (noisiness) morphing
envelopes, and return the morphed Partials in a PartialList.

Optionally specify the labels of the Partials to be used as 
reference Partial for the two morph sources. The reference 
partial is used to compute frequencies for very low-amplitude 
Partials whose frequency estimates are not considered reliable. 
The reference Partial is considered to have good frequency 
estimates throughout. A reference label of 0 indicates that 
no reference Partial should be used for the corresponding
morph source.

Loris morphs Partials by interpolating frequency, amplitude,
and bandwidth envelopes of corresponding Partials in the
source PartialLists. For more information about the Loris
morphing algorithm, see the Loris website:
	www.cerlsoundgroup.org/Loris/") morph;

%newobject morph;
%inline %{
	PartialList * morph( const PartialList * src0, const PartialList * src1, 
                         const Envelope * ffreq, 
                         const Envelope * famp, 
                         const Envelope * fbw )
	{
		PartialList * dst = createPartialList();
		
		notifier << "morphing " << src0->size() << " Partials with " <<
					src1->size() << " Partials" << endl;
		try
		{			
			//	make a Morpher object and do it:
			Morpher m( *ffreq, *famp, *fbw );
			m.enableLogAmpMorphing( DoLogAmplitudeMorphing );
			m.enableLogFreqMorphing( DoLogFrequencyMorphing );
			
			m.morph( src0->begin(), src0->end(), src1->begin(), src1->end() );
					
			//	splice the morphed Partials into dst:
			dst->splice( dst->end(), m.partials() );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );

			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
	
	PartialList * morph( const PartialList * src0, const PartialList * src1, 
                         double freqweight, 
                         double ampweight, 
                         double bwweight )
	{
		LinearEnvelope ffreq( freqweight ), famp( ampweight ), fbw( bwweight );
		
		PartialList * dst = createPartialList();
		
		notifier << "morphing " << src0->size() << " Partials with " <<
					src1->size() << " Partials" << endl;
		try
		{			
			//	make a Morpher object and do it:
			Morpher m( ffreq, famp, fbw );
			m.enableLogAmpMorphing( DoLogAmplitudeMorphing );
			m.enableLogFreqMorphing( DoLogFrequencyMorphing );
			
			m.morph( src0->begin(), src0->end(), src1->begin(), src1->end() );
					
			//	splice the morphed Partials into dst:
			dst->splice( dst->end(), m.partials() );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );

			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}

	PartialList * morph( const PartialList * src0, const PartialList * src1,
	                     long src0RefLabel, long src1RefLabel,
                         const Envelope * ffreq, 
                         const Envelope * famp, 
                         const Envelope * fbw )
	{
		PartialList * dst = createPartialList();
		
		notifier << "morphing " << src0->size() << " Partials with " <<
					src1->size() << " Partials" << endl;
		try
		{			
			//	make a Morpher object and do it:
			Morpher m( *ffreq, *famp, *fbw );
			m.enableLogAmpMorphing( DoLogAmplitudeMorphing );
			m.enableLogFreqMorphing( DoLogFrequencyMorphing );
			

			if ( src0RefLabel != 0 )
			{
			   notifier << "using Partial labeled " << src0RefLabel;
			   notifier << " as reference Partial for first morph source" << endl;
			   m.setSourceReferencePartial( *src0, src0RefLabel );
			}
			else
			{
			   notifier << "using no reference Partial for first morph source" << endl;
			}

			if ( src1RefLabel != 0 )
			{
			   notifier << "using Partial labeled " << src1RefLabel;
			   notifier << " as reference Partial for second morph source" << endl;
			   m.setTargetReferencePartial( *src1, src1RefLabel );
			}
			else
			{
			   notifier << "using no reference Partial for second morph source" << endl;
			}			
			
			
			m.morph( src0->begin(), src0->end(), src1->begin(), src1->end() );
					
			//	splice the morphed Partials into dst:
			dst->splice( dst->end(), m.partials() );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );

			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
	
	PartialList * morph( const PartialList * src0, const PartialList * src1, 
	                     long src0RefLabel, long src1RefLabel,
                         double freqweight, 
                         double ampweight, 
                         double bwweight )
	{
		LinearEnvelope ffreq( freqweight ), famp( ampweight ), fbw( bwweight );
		
		PartialList * dst = createPartialList();
		
		notifier << "morphing " << src0->size() << " Partials with " <<
					src1->size() << " Partials" << endl;
		try
		{			
			//	make a Morpher object and do it:
			Morpher m( ffreq, famp, fbw );
			m.enableLogAmpMorphing( DoLogAmplitudeMorphing );
			m.enableLogFreqMorphing( DoLogFrequencyMorphing );
			

			if ( src0RefLabel != 0 )
			{
			   notifier << "using Partial labeled " << src0RefLabel;
			   notifier << " as reference Partial for first morph source" << endl;
			   m.setSourceReferencePartial( *src0, src0RefLabel );
			}
			else
			{
			   notifier << "using no reference Partial for first morph source" << endl;
			}

			if ( src1RefLabel != 0 )
			{
			   notifier << "using Partial labeled " << src1RefLabel;
			   notifier << " as reference Partial for second morph source" << endl;
			   m.setTargetReferencePartial( *src1, src1RefLabel );
			}
			else
			{
			   notifier << "using no reference Partial for second morph source" << endl;
			}			
			
			
			m.morph( src0->begin(), src0->end(), src1->begin(), src1->end() );
					
			//	splice the morphed Partials into dst:
			dst->splice( dst->end(), m.partials() );
		}
		catch ( std::exception & ex )
		{
			throw_exception( ex.what() );

			destroyPartialList( dst );
			dst = NULL;
		}
		return dst;
	}
%}

%feature("docstring",
"Set the shaping parameter for the amplitude morphing
function. 

DEPRECATED - DO NOT USE
") morpher_setAmplitudeShape;

%rename( setAmplitudeMorphShape ) morpher_setAmplitudeShape;

void morpher_setAmplitudeShape( double shape );

const double LORIS_DEFAULT_AMPMORPHSHAPE;    
const double LORIS_LINEAR_AMPMORPHSHAPE;

