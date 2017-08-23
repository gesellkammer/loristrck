# cython: embedsignature=True
# cython: boundscheck=False
# cython: wraparound=False

import warnings
from libcpp.string cimport string
from libcpp.vector cimport vector
cimport lorisdefs as loris
cimport cython
from cython.operator cimport dereference as deref, preincrement as inc
import numpy as _np
cimport numpy as _np
from numpy.math cimport INFINITY
from libc.math cimport ceil
import logging
import sys

ctypedef _np.float64_t SAMPLE_t

logger = logging.getLogger("loristrck")
    
_np.import_array()
  
def analyze(double[::1] samples not None, double sr, double resolution, double windowsize= -1, 
            double hoptime =-1, double freqdrift =-1, double sidelobe=-1,
            double ampfloor=-90, double croptime=-1, outfile=None):

    """
    Partial Tracking Analysis
    =========================

    Analyze the audio samples.
    Returns a list of 2D numpy arrays, where each array represent a partial with
    columns: [time, freq, amplitude, phase, bandwidth]

    If outfile is given, a sdif file is saved with the results of the analysis

    Arguments
    =========

    * samples: numpy.ndarray
        An array representing a mono sndfile.   
    * sr: int
        The sampling rate
    * resolution: Hz 
        Only one partial will be found within this distance. 
        Usual values range from 30 Hz to 200 Hz.
    * windowsize: Hz.
        If not given, a default value is calculated. The size
        of the window in samples can be calculated: 
        windowsize_in_samples = sr / windowsize_in_hz
        "Should be approx. equal to, and never more than twice the freq.
         resolution"

    The rest of the parameters are set with sensible defaults if not given explicitely.
    (a value of -1 indicates that a default value should be set)

    * hoptime: sec
        The time to move the window after each analysis. 
        Default: 1/windowWidth. "hop time in secs is the inverse of the window width
        really. Smith and Serra say: a good choice of hop is the window length
        divided by the main lobe width in freq. samples, which turns out to be 
        just the inverse of the width.
    * freqdrift: Hz  
        The maximum variation of frecuency between two breakpoints to be
        considered to belong to the same partial. A sensible value is
        between 1/2 to 3/4 of resolution
    * sidelobe: dB
        A positive dB value, indicates the shape of the Kaiser window
        (typical value: 90 dB)
    * ampfloor: dB  
        A breakpoint with an amplitude lower than this value will not 
        be considered
    * croptime: secs. Is the max. time correction beyond which a seassigned 
        spectral component is considered inreliable, and not eligible for
        breakpoint formation. Default: the hop time. Should it be half that?
    
    """
    if windowsize < 0:
        windowsize = resolution * 2  # original Loris behaviour
    cdef loris.Analyzer* an = new loris.Analyzer(resolution, windowsize)
    if hoptime > 0:
        logger.info("Setting hoptime for Analyzer: {0}".format(hoptime))
        an.setHopTime(hoptime)
    if freqdrift > 0:
        an.setFreqDrift(freqdrift)
    if sidelobe > 0:
        an.setSidelobeLevel( sidelobe )
    if croptime > 0:
        an.setCropTime( croptime )
    an.setAmpFloor(ampfloor)
    logger.info("analysis: windowsize={0}, hoptime={1}, freqDrift={2}".format(
        an.windowWidth(), an.hopTime(), an.freqDrift()))

    cdef double *samples0 = &(samples[0])              #<double*> _np.PyArray_DATA(samples)
    cdef double *samples1 = &(samples[<int>(samples.size-1)]) #samples0 + <int>(samples.size - 1)
    cdef loris.PartialList partials = an.analyze(samples0, samples1, sr)
    del an
    cdef loris.SdifFile* sdiffile
    cdef string filename
    if outfile is not None:
        if not isinstance(outfile, bytes):
            outfile = outfile.encode("ASCII", errors="ignore")
        filename = string(<char*>outfile)
        sdiffile = new loris.SdifFile(partials.begin(), partials.end())
        with nogil:
            sdiffile.write(filename)
        del sdiffile 
    out = PartialList_toarray(&partials)
    return out


cdef list PartialList_toarray(loris.PartialList* partials):
    cdef loris.PartialListIterator p_it = partials.begin()
    cdef loris.PartialListIterator p_end = partials.end()
    cdef loris.Partial partial
    cdef list out = []
    while p_it != p_end:
        partial = deref(p_it)
        out.append(Partial_toarray(&partial))
        inc(p_it)
    return out


cdef _np.ndarray Partial_toarray(loris.Partial* p):
    cdef int numbps = p.numBreakpoints()
    cdef _np.ndarray [SAMPLE_t, ndim=2] arr = _np.empty((numbps, 5), dtype='float64')
    cdef double *data = <double *>arr.data
    cdef loris.Partial_Iterator it  = p.begin()
    cdef loris.Partial_Iterator end = p.end()
    cdef loris.Breakpoint *bp
    cdef double time
    cdef int i = 0
    cdef double *row
    while it != end:
        bp = &(it.breakpoint())
        row = data + 5*i
        row[0] = it.time()
        row[1] = bp.frequency()
        row[2] = bp.amplitude()
        row[3] = bp.phase()
        row[4] = bp.bandwidth()
        i += 1
        inc(it)
    if i != numbps:
        print("ERROR: numbps=%d,  i=%d" % (numbps, i))
    return arr


cdef inline loris.Breakpoint* newBreakpoint(double f, double a, double ph, double bw):
    cdef loris.Breakpoint* out = new loris.Breakpoint(f, a, bw)
    out.setPhase(ph)
    return out


cdef loris.Partial* newPartial_fromarray(_np.ndarray[SAMPLE_t, ndim=2] a, float fadetime=0):
    cdef loris.Partial *p = new loris.Partial()
    cdef int numbps = len(a)
    cdef loris.Breakpoint *bp 
    cdef double *row   
    cdef double t
    cdef int i
    if a.shape[1] != 5:
        return NULL
    if a[0, 0] < 0:
        return NULL
    if a.flags.c_contiguous:
        row = (<double *>a.data)
        for i in range(numbps):
            bp = newBreakpoint(row[1], row[2], row[3], row[4])
            p.insert(row[0], deref(bp))
            del bp
            # TODO: fix the copying by using std::move
            row += 5
    else:
        for i in range(numbps):
            bp = newBreakpoint(a[i, 1], a[i, 2], a[i, 3], a[i, 4])
            p.insert(a[i, 0], deref(bp))
            del bp
    if fadetime > 0:
        p.fadeIn(fadetime)
        p.fadeOut(fadetime)
    return p


def test_conversion(m):
    cdef loris.Partial *p = newPartial_fromarray(m)
    m2 = Partial_toarray(p)
    print(len(m), p.numBreakpoints(), len(m2))
    del p
    return m2


def test_conversion2(ms):
    cdef loris.Partial *p
    cdef loris.PartialList *pl = new loris.PartialList()
    for m in ms:
        p = newPartial_fromarray(m)
        pl.push_back(deref(p))
        del p
    ms2 = PartialList_toarray(pl)
    del pl
    return ms2
    

def read_sdif(path):
    """
    Read the SDIF file

    sdiffile: (str) The path to a SDIF file

    Returns
    =======

    (list of partialdata, labels)

    Partialdata is a a list of 2D matrices. Each matrix is a partial, 
    where each row is a breakpoint of the form (time, freq, amp, phase, bw)

    labels: a list of the labels for each partial
    """
    cdef loris.SdifFile* sdif
    cdef loris.PartialList partials
    if not isinstance(path, bytes):
        path = path.encode("ASCII", errors="ignore")
    cdef string filename = string(<char*>path)
    sdif = new loris.SdifFile(filename)
    partials = sdif.partials()
    cdef loris.PartialListIterator p_it = partials.begin()
    cdef loris.PartialListIterator p_end = partials.end()
    cdef loris.Partial partial
    cdef list matrices = []
    cdef list labels = []
    while p_it != p_end:
        partial = deref(p_it)
        matrices.append(Partial_toarray(&partial))
        labels.append(partial.label())
        inc(p_it)
    del sdif
    return (matrices, labels)


def _isiterable(seq):
    return hasattr(seq, '__iter__') and not isinstance(seq, (str, bytes))


cdef class PartialListW:
    cdef loris.PartialList *thisptr
    
    def __dealloc__(self):
        PartialList_destroy(self.thisptr)
        
    def dump(self):
        PartialList_dump(self.thisptr)

    def setlabels(self, labels):
        """
        labels: a seq. of int
        """
        assert _isiterable(labels)
        PartialList_setlabels(self.thisptr, labels)

    def toarray(self):
        """
        Returns a list of arrays, where each array represents one
        Partial, where each row is a breakpoint. The columns are:
        time, freq, amp, phase, bw
        """
        return PartialList_toarray(self.thisptr)

    def __len__(self):
        return self.thisptr.size()


cpdef PartialListW newPartialList(dataseq, labels=None, double fadetime=0):
    cdef loris.PartialList *plist = PartialList_fromdata(dataseq, fadetime)
    cdef PartialListW self = PartialListW()
    self.thisptr = plist
    if labels is not None:
        if isinstance(labels, int):
            labels = [labels] * len(self)
        self.setlabels(labels)
    return self


def write_sdif(partials, outfile, labels=None, rbep=True, double fadetime=0):
    """
    Write a list of partials in the sdif 
    
    partials: a seq. of 2D arrays with columns [time freq amp phase bw]
    outfile: the path of the sdif file
    labels: a seq. of integer labels, or None to skip saving labels
    rbep: if True, use RBEP format, otherwise, 1TRC

    NB: The 1TRC format forces resampling
    """
    assert _isiterable(partials)
    cdef loris.PartialList *ps = PartialList_fromdata(partials, fadetime)
    logger.debug("Converted to PartialList. Num. partials: %d", ps.size())
    cdef loris.SdifFile* sdiffile = new loris.SdifFile(ps.begin(), ps.end())
    if not isinstance(outfile, bytes):
        outfile = outfile.encode("ASCII", errors="inore")
    cdef string filename = string(<char*>outfile)
    cdef int use_rbep = int(rbep)
    logger.debug("Writing SDIF")
    with nogil:
        if use_rbep:
            sdiffile.write(filename)
        else:
            sdiffile.write1TRC(filename)
    logger.debug("Finished writing SDIF")
    del sdiffile
    PartialList_destroy(ps)
    

cdef void PartialList_destroy(loris.PartialList *partials):
    logger.info("destroy")
    del partials 


cdef void PartialList_setlabels(loris.PartialList *partial_list, labels):
    cdef loris.PartialListIterator p_it = partial_list.begin()
    cdef loris.PartialListIterator p_end = partial_list.end()
    cdef loris.Partial partial
    for label in labels:
        assert isinstance(label, int)
        partial = deref(p_it)
        partial.setLabel(int(label))
        inc(p_it)
        if p_it == p_end:
            break

cdef void PartialList_dump(loris.PartialList *plist):
    cdef loris.PartialListIterator p_it = plist.begin()
    cdef loris.PartialListIterator p_end = plist.end()
    cdef loris.Partial partial
    cdef int label
    cdef int idx = 0
    cdef loris.Partial_Iterator it
    cdef loris.Partial_Iterator end
    cdef loris.Breakpoint *bp
    while p_it != p_end:
        partial = deref(p_it)
        label = partial.label()
        print("Idx: %d  Label: %d" % (idx, label))
        it = partial.begin()
        end = partial.end()
        while it != end:
            bp = &(it.breakpoint())
            print("t=%.4f  f=%.2f  a=%.6f  ph=%.6f  bw=%f" % 
                  (it.time(), bp.frequency(), bp.amplitude(), bp.phase(), bp.bandwidth())
            )
            inc(it)
        inc(p_it)
        idx += 1
        
        
cdef loris.PartialList* PartialList_fromdata(dataseq, double fadetime=0):
    """
    dataseq: a seq. of 2D double arrays, each array represents a partial
    
    NB: to set the labels of the partials, call PartialList_setlabels
    """
    cdef loris.PartialList *partials = new loris.PartialList()
    cdef loris.Partial *partial = NULL
    cdef int i = 0
    cdef int label
    for matrix in dataseq:
        partial = newPartial_fromarray(matrix, fadetime)
        if partial != NULL:
            partials.push_back(deref(partial))
            del partial # fix this: use std::move
            i += 1
        else:
            logger.error("Error creating partial from matrix: %s" % str(matrix))
    return partials


def read_aiff(path):
    """
    Read a mono AIFF file (Loris does not read stereo files)

    path: (str) The path to the soundfile (.aif or .aiff)

    NB: Raises ValueError if the soundfile is not mono

    --> A tuple (audiodata, samplerate)

    audiodata : 1D numpy array of type double, holding the samples
    """
    cdef loris.AiffFile* aiff = new loris.AiffFile(string(<char*>path))
    cdef vector[double] samples = aiff.samples()
    cdef double[:] mono
    cdef vector[double].iterator it
    cdef int channels = aiff.numChannels()
    cdef double samplerate = aiff.sampleRate()
    if channels != 1:
        raise ValueError("Can only read mono files")
    cdef int numFrames = aiff.numFrames()
    mono = _np.empty((numFrames,), dtype='float64')
    it = samples.begin()
    cdef int i = 0
    while i < numFrames:
        mono[i] = deref(it)
        i += 1
        inc(it)
    del aiff
    return (mono, samplerate)

        
cdef object PartialList_timespan(loris.PartialList * partials):
    cdef loris.PartialListIterator it = partials.begin()
    cdef loris.PartialListIterator end = partials.end()
    cdef loris.Partial partial = deref(it)
    cdef double tmin = partial.startTime()
    cdef double tmax = partial.endTime()
    while it != end:
        partial = deref(it)
        tmin = min(tmin, partial.startTime())
        tmax = max(tmax, partial.endTime())
        inc(it)
    return tmin, tmax


def synthesize(dataseq, int samplerate, double fadetime=-1):
    """
    dataseq:    a seq. of 2D matrices, each matrix represents a partial
                Each row is a breakpoint of the form [time freq amp phase bw]
    
    samplerate: the samplerate of the synthesized samples (Hz)
    
    fadetime:   to avoid clicks, partials not ending in 0 amp should be faded
                If negative, a sensible default is used (seconds)

    --> samples: numpy 1D array of doubles holding the samples
    """
    if fadetime < 0:
        fadetime = 64.0 / samplerate
    cdef list matrices = dataseq if isinstance(dataseq, list) else list(dataseq)
    cdef _np.ndarray [SAMPLE_t, ndim=2] m
    cdef double t0 = INFINITY
    cdef double t1 = 0
    cdef double mt0, mt1
    for m in matrices:
        mt0 = m[0, 0]
        if mt0 < t0:
            t0 = mt0
        mt1 = m[m.shape[0]-1, 0]
        if mt1 > t1:
            t1 = mt1
    cdef int numsamples = int((t1 + fadetime) * samplerate)+1
    cdef vector[double] bufvector;
    bufvector.resize(numsamples)
    cdef int i = 0
    cdef loris.Synthesizer *synthesizer = new loris.Synthesizer(samplerate, bufvector, fadetime)
    cdef loris.Partial *lorispartial
    for m in matrices:
        if m[0, 0] < 0:
            logger.warn("synthesize: Partial with negative times found, skipping")
            continue
        lorispartial = newPartial_fromarray(m)
        if lorispartial != NULL:
            synthesizer.synthesize(lorispartial[0])
            del lorispartial
        else:
            print("synthetize: NULL partial")
    cdef size_t offset = int(t0*samplerate)
    cdef double[::1] buf = _np.zeros((numsamples,), dtype=float)
    # cdef _np.ndarray [SAMPLE_t, ndim=1] buf = _np.zeros((numsamples,), dtype='float64')
    
    for i in range(offset, numsamples):
        buf[i] = bufvector[i]
    del synthesizer
    return _np.asarray(buf)
    

cdef object PartialList_estimatef0(loris.PartialList *plist, 
                                   double minfreq, double maxfreq, double interval):
    cdef double precission_in_hz = 0.1
    cdef double confidence = 0.9
    cdef loris.FundamentalFromPartials* est = new loris.FundamentalFromPartials(precission_in_hz)
    cdef double t0, t1
    t0, t1 = PartialList_timespan(plist)
    cdef loris.LinearEnvelope env = est.buildEnvelope(
        plist.begin(), plist.end(), t0, t1, interval, minfreq, maxfreq, confidence)
    out = LinearEnvelope_toarray(&env, t0, t1, interval)
    del est
    return (out, t0, t1)


cdef void F0Estimate_getdata(loris.F0Estimate f0, double *out):
    out[0] = f0.frequency()
    out[1] = f0.confidence()
    # return f0.frequency(), f0.confidence()


cdef tuple PartialList_estimatef0_with_confidence(loris.PartialList *plist, 
                                                   double minfreq, double maxfreq, 
                                                   double interval, double precission_in_hz=0.1):
    cdef loris.FundamentalFromPartials *est = new loris.FundamentalFromPartials(precission_in_hz)
    cdef double t0, t1
    t0, t1 = PartialList_timespan(plist)
    cdef long i = 0
    cdef long numelements = arange_numelements(t0, t1, interval)
    cdef double t
    cdef double[2] data
    cdef double[:] freqs = _np.zeros((numelements,), dtype='float64')
    cdef double[:] confs = _np.zeros((numelements,), dtype='float64')
    data[0] = 0
    data[1] = 0
    while i < numelements:
        t = t0 + i*interval
        F0Estimate_getdata(est.estimateAt(plist.begin(), plist.end(), t, minfreq, maxfreq), &(data[0]))
        freqs[i] = data[0]
        confs[i] = data[1]
        i += 1
    del est
    return freqs, confs, t0, t1


def estimatef0(matrices, double minfreq, double maxfreq, double interval):
    """
    Estimate the fundamental 

    * matrices: a seq. of numpy 2D matrices, each matrix representing a partial
    * minfreq, maxfreq: freq. range where to look for a fundamental
    * interval: the time resolution of the fundamental

    Returns freqs, confidencies, t0, t1

    * freqs: numpy.array. The frequencies of the f0
    * confidences: numpy.array, same size as freqs, contains the confiency of 
                   each freq value
    * t0, t1: the timespan of this spectrum. To calculate the times axes, use
              numpy.arange(t0, t1, interval)

    These represent a linear interpolation of the frequency of the fundamental
    within the timespan t0-t1 with a grid defined by `interval`.
    To each freq. value there is a confidency value, where 1 represents maximum
    confidency, and values below 0.9 indicate unvoiced or very faint sounds. 

    Example 1
    =========

    import scipy.interpolate
    matrices, labels = read_sdif("path/to/sdif")
    dt = 0.05  # estimate f0 at a 50 ms interval
    freqs, confidencies, t0, t1 = estimatef0(matrices, 50, 2000, dt)
    freqs *= confidences > 0.9
    times = numpy.arange(t0, t1, dt)
    f0 = scipy.interpolate.interp1d(times, freqs)

    or f0 = bpf.core.Sampled(freqs, dt, t0)

    print(f0(0.8))
    """
    cdef loris.PartialList *pl = PartialList_fromdata(matrices, 0)
    out = PartialList_estimatef0_with_confidence(pl, minfreq, maxfreq, interval)
    del pl
    return out


cdef long arange_numelements(double x0, double x1, double step):
    return <long>(ceil((x1-x0)/step))


cdef _np.ndarray LinearEnvelope_toarray(loris.LinearEnvelope* env, double x0, double x1, double interval):
    cdef double x = x1
    cdef double y
    cdef long i = 0
    cdef long numelements = arange_numelements(x0, x1, interval)
    # cdef _np.ndarray[double, ndim=1] out = _np.zeros((numelements,), dtype='float64')
    cdef double[::1] out = _np.empty((numelements,), dtype='float64')
    while i < numelements:
        x = x0 + interval*i
        y = env.valueAt(x)
        out[i] = y
        i += 1
    return _np.asarray(out)
