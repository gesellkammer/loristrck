from libcpp.string cimport string
from libcpp.vector cimport vector

cdef extern from "../src/loris/src/Breakpoint.h" namespace "Loris":
    cdef cppclass Breakpoint "Loris::Breakpoint":
        Breakpoint( double f, double a, double b, double p=0.)
        double frequency()
        double amplitude()
        double bandwidth()
        double phase()
        void setAmplitude(double x)
        void setBandwidth(double x)
        void setFrequency(double x)
        void setPhase(double x)
        
cdef extern from "../src/loris/src/Partial.h" namespace "Loris":
    cppclass Partial_Iterator "Loris::Partial_Iterator"
    cppclass Partial "Loris::Partial":
        double startTime()
        double endTime()
        int numBreakpoints()
        int label()
        void setLabel( int label )
        double duration()
        Partial_Iterator begin()
        Partial_Iterator end()
        Partial_Iterator insert( double time, Breakpoint & bp )
        Breakpoint & first()
        Breakpoint & last()
        double phaseAt( double time )
        # void fadeIn( double fadeTime )
        # void fadeOut( double fadeTime )
        void clear()
        Partial_Iterator erase(Partial_Iterator, Partial_Iterator)
        
    cppclass Partial_Iterator "Loris::Partial_Iterator":
        Breakpoint & breakpoint()
        double time()
        bint operator== (Partial_Iterator)
        bint operator!= (Partial_Iterator)
        Partial_Iterator operator++()
        
cdef extern from "../src/loris/src/PartialList.h" namespace "Loris":
    cppclass PartialListIterator "Loris::PartialListIterator"
    cppclass PartialList "Loris::PartialList":
        PartialListIterator begin()
        PartialListIterator end()
        PartialListIterator erase(PartialListIterator, PartialListIterator);
        void push_back(Partial& p)
        Partial& front()
        void clear()
        bint empty()
        unsigned int size()

    cppclass PartialListIterator "Loris::PartialListIterator":
        bint operator== (PartialListIterator)
        bint operator!= (PartialListIterator)
        Partial& operator* ()
        PartialListIterator operator++()
        #PartialListIterator begin()
        #PartialListIterator end()
        #PartialListIterator erase(PartialListIterator, PartialListIterator);
        


cdef extern from "../src/loris/src/Analyzer.h" namespace "Loris":
    cppclass Analyzer "Loris::Analyzer":
        Analyzer(double resolution, double window_width)
        void configure( double resolution, double window_width )
        PartialList analyze( double* buffer, double* buffend, double srate)
        PartialList & partials()
        void setHopTime( double )
        void setFreqDrift( double )
        void setSidelobeLevel( double )
        void setAmpFloor( double )
        void setCropTime( double )
        double hopTime()
        double freqDrift()
        double windowWidth()
        double sidelobeLevel()
        void storeResidueBandwidth( double regionWidth )
        void storeConvergenceBandwidth( double tolerance )

cdef extern from "../src/loris/src/Synthesizer.h" namespace "Loris":
    cppclass Synthesizer "Loris::Synthesizer":
        Synthesizer(double srate, vector[double] &buffer, double fadeTime)
        void synthesize( Partial p )
    
cdef extern from "../src/loris/src/SdifFile.h" namespace "Loris":
    cppclass SdifFile "Loris::SdifFile":
        SdifFile( string & filename )  # to convert from python string: string(<char*>pythonstring)
        SdifFile( PartialListIterator begin, PartialListIterator end )
        PartialList & partials()
        void addPartial( Partial & p)
        void addPartials( PartialListIterator begin, PartialListIterator end )
        void write( string & path ) nogil
        void write1TRC( string & path ) nogil

cdef extern from "../src/loris/src/AiffFile.h" namespace "Loris":
    cppclass AiffFile "Loris::AiffFile":
        AiffFile( string & filename)
        unsigned int numChannels()
        unsigned int numFrames()
        double sampleRate()
        vector[double] & samples()

cdef extern from "../src/loris/src/LinearEnvelope.h" namespace "Loris":
    cppclass LinearEnvelope "Loris::LinearEnvelope":
        # virtual double valueAt( double t ) const;
        double valueAt(double t)

cdef extern from "../src/loris/src/F0Estimate.h" namespace "Loris":
    cppclass F0Estimate "Loris::F0Estimate":
        double frequency()
        double confidence()

cdef extern from "../src/loris/src/Fundamental.h" namespace "Loris":
    cppclass FundamentalFromPartials:
        FundamentalFromPartials(double Precision)
        F0Estimate estimateAt(PartialListIterator begin,
                              PartialListIterator end,
                              double time,
                              double lowerFreqBound, double upperFreqBound)
        LinearEnvelope buildEnvelope(
            PartialListIterator begin, PartialListIterator end,
            double tbeg, double tend,
            double interval, 
            double lowerFreqBound, double upperFreqBound,
            double confidenceThreshold)

# cdef extern from "../src/loris/src/loris.h": #  namespace "Loris":
#    void resample( PartialList * partials, double interval )
#    void shapeSpectrum( PartialList * partials, PartialList * surface,
#                        double stretchFreq, double stretchTime )
#    void collate( PartialList * partials );

cdef extern from "../src/loris/src/Oscillator.h":
    cppclass Oscillator:
        Oscillator()
        void resetEnvelopes(const Breakpoint & bp, double srate )
        void setPhase(double ph)
        double amplitude()
        double bandwidth()
        double phase()
        double radianFreq()
        void oscillate(double * begin, double * end, const Breakpoint &bp, double srate)


#cdef extern from "../src/loris/src/Collator.h":
#    cppclass Collator:
#        Collator( double partialFadeTime, double partialSilentTime )
#        Partial_Iterator collate( PartialList & partials )
    
