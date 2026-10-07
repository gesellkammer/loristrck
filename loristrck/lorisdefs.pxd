from libcpp.string cimport string
from libcpp.vector cimport vector

cdef extern from "../src/loris/src/Breakpoint.h" namespace "Loris":
    cdef cppclass Breakpoint "Loris::Breakpoint":
        Breakpoint(double f, double a, double b, double p=0.) except +
        double frequency() except +
        double amplitude() except +
        double bandwidth() except +
        double phase() except +
        void setAmplitude(double x) except +
        void setBandwidth(double x) except +
        void setFrequency(double x) except +
        void setPhase(double x) except +
        
cdef extern from "../src/loris/src/Partial.h" namespace "Loris":
    cppclass Partial_Iterator "Loris::Partial_Iterator"
    cppclass Partial "Loris::Partial":
        double startTime() except +
        double endTime() except +
        int numBreakpoints() except +
        int label() except +
        void setLabel(int label) except +
        double duration() except +
        Partial_Iterator begin() except +
        Partial_Iterator end() except +
        Partial_Iterator insert(double time, Breakpoint & bp) except +
        Breakpoint & first() except +
        Breakpoint & last() except +
        double phaseAt(double time) except +
        # void fadeIn( double fadeTime )
        # void fadeOut( double fadeTime )
        void clear() except +
        Partial_Iterator erase(Partial_Iterator, Partial_Iterator) except +

    cppclass Partial_Iterator "Loris::Partial_Iterator":
        Breakpoint & breakpoint() except +
        double time() except +
        bint operator== (Partial_Iterator) except +
        bint operator!= (Partial_Iterator) except +
        Partial_Iterator operator++() except +
        
cdef extern from "../src/loris/src/PartialList.h" namespace "Loris":
    cppclass PartialListIterator "Loris::PartialListIterator"
    cppclass PartialList "Loris::PartialList":
        PartialListIterator begin() except +
        PartialListIterator end() except +
        PartialListIterator erase(PartialListIterator, PartialListIterator) except +
        void push_back(Partial& p) except +
        Partial& front() except +
        void clear() except +
        bint empty() except +
        unsigned int size() except +

    cppclass PartialListIterator "Loris::PartialListIterator":
        bint operator== (PartialListIterator) except +
        bint operator!= (PartialListIterator) except +
        Partial& operator* () except +
        PartialListIterator operator++() except +
        #PartialListIterator begin()
        #PartialListIterator end()
        #PartialListIterator erase(PartialListIterator, PartialListIterator);
        


cdef extern from "../src/loris/src/Analyzer.h" namespace "Loris":
    cppclass Analyzer "Loris::Analyzer":
        Analyzer(double resolution, double window_width) except +
        void configure(double resolution, double window_width) except +
        PartialList analyze(double* buffer, double* buffend, double srate) except +
        PartialList & partials() except +
        void setHopTime(double) except +
        void setFreqDrift(double) except +
        void setSidelobeLevel(double) except +
        void setAmpFloor(double) except +
        void setCropTime(double) except +
        double hopTime() except +
        double freqDrift() except +
        double windowWidth() except +
        double sidelobeLevel() except +
        void storeResidueBandwidth(double regionWidth) except +
        void storeConvergenceBandwidth(double tolerance) except +

cdef extern from "../src/loris/src/Synthesizer.h" namespace "Loris":
    cppclass Synthesizer "Loris::Synthesizer":
        Synthesizer(double srate, vector[double] &buffer, double fadeTime) except +
        void synthesize(Partial p) except +

cdef extern from "../src/loris/src/SdifFile.h" namespace "Loris":
    cppclass SdifFile "Loris::SdifFile":
        SdifFile(string & filename) except +  # to convert from python string: string(<char*>pythonstring)
        SdifFile(PartialListIterator begin, PartialListIterator end) except +
        PartialList & partials() except +
        void addPartial(Partial & p) except +
        void addPartials(PartialListIterator begin, PartialListIterator end) except +
        void write(string & path) except + nogil
        void write1TRC(string & path) except + nogil

cdef extern from "../src/loris/src/AiffFile.h" namespace "Loris":
    cppclass AiffFile "Loris::AiffFile":
        AiffFile(string & filename) except +
        unsigned int numChannels() except +
        unsigned int numFrames() except +
        double sampleRate() except +
        vector[double] & samples() except +

cdef extern from "../src/loris/src/LinearEnvelope.h" namespace "Loris":
    cppclass LinearEnvelope "Loris::LinearEnvelope":
        # virtual double valueAt( double t ) const;
        double valueAt(double t) except +

cdef extern from "../src/loris/src/Fundamental.h" namespace "Loris":
    cppclass FundamentalFromPartials:
        FundamentalFromPartials(double Precision) except +
        LinearEnvelope buildEnvelope(
            PartialListIterator begin, PartialListIterator end,
            double tbeg, double tend,
            double interval,
            double lowerFreqBound, double upperFreqBound,
            double confidenceThreshold) except +

cdef extern from *:
    """
    #include "../src/loris/src/Fundamental.h"

    static void loristrck_estimate_f0(
        Loris::FundamentalFromPartials *est,
        Loris::PartialListIterator begin,
        Loris::PartialListIterator end,
        double time,
        double lower_freq_bound,
        double upper_freq_bound,
        double *out)
    {
        const Loris::F0Estimate estimate = est->estimateAt(
            begin, end, time, lower_freq_bound, upper_freq_bound);
        out[0] = estimate.frequency();
        out[1] = estimate.confidence();
    }
    """
    void loristrck_estimate_f0(FundamentalFromPartials *est,
                               PartialListIterator begin,
                               PartialListIterator end,
                               double time,
                               double lower_freq_bound,
                               double upper_freq_bound,
                               double *out) except +

# cdef extern from "../src/loris/src/loris.h": #  namespace "Loris":
#    void resample( PartialList * partials, double interval )
#    void shapeSpectrum( PartialList * partials, PartialList * surface,
#                        double stretchFreq, double stretchTime )
#    void collate( PartialList * partials );

cdef extern from "../src/loris/src/Oscillator.h":
    cppclass Oscillator:
        Oscillator() except +
        void resetEnvelopes(const Breakpoint & bp, double srate) except +
        void setPhase(double ph) except +
        double amplitude() except +
        double bandwidth() except +
        double phase() except +
        double radianFreq() except +
        void oscillate(double * begin, double * end, const Breakpoint &bp, double srate) except +


#cdef extern from "../src/loris/src/Collator.h":
#    cppclass Collator:
#        Collator( double partialFadeTime, double partialSilentTime )
#        Partial_Iterator collate( PartialList & partials )
    
