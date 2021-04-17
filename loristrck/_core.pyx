# cython: embedsignature=True
# cython: boundscheck=False
# cython: wraparound=False

import warnings
from libcpp.string cimport string
from libcpp.vector cimport vector
cimport lorisdefs as loris
cimport cython
from cython.operator cimport dereference as deref, preincrement as inc
import numpy as np
cimport numpy as _np
from numpy.math cimport INFINITY
from libc.math cimport ceil, sqrt, pi, pow
import logging
import sys
import os


ctypedef _np.float64_t SAMPLE_t

logger = logging.getLogger("loristrck")
    
_np.import_array()


def analyze(double[::1] samples not None, double sr, double resolution, double windowsize= -1, 
            double hoptime =-1, double freqdrift =-1, double sidelobe=-1,
            double ampfloor=-90, double croptime=-1, 
            double residuebw=-1, double convergencebw=-1,
            outfile=None):
    """
    Partial Tracking Analysis
    
    Analyze the audio samples. Returns a list of 2D numpy arrays, where each array 
    represent a partial with columns: [time, freq, amplitude, phase, bandwidth]
    If outfile is given, a sdif file is saved with the results of the analysis

    There are three categories of analysis parameters:

    - the resolution and params related to it (freq. floor and drift)
    - the window width and params related to it (hop and crop times)
    - independent parameters (bw region width and amp floor)

    Args:
        samples: numpy.ndarray. An array representing a mono sndfile.   
        sr: int (Hz). The sampling rate
        resolution: Hz. Only one partial will be found within this distance. 
            Usual values range from 30 Hz to 200 Hz. As a rule of thumb, when tracking a
            monophonic source, resolution ~= min(f0) * 0.9
            So if the source is a male voice dropping down to 70 Hz, resolution=60 Hz 
        windowsize: Hz. Is the main lobe width of the Kaiser analysis window in Hz 
            (main-lobe, zero to zero). If not given, a default value is calculated. 
            The size of the window in samples can be calculated by:
            `util.kaiserLength(windowsize, sr, sidelobe)`
        hoptime: sec. The time to move the window after each analysis. 
            Default: 1/windowsize. "hop time in secs is the inverse of the window width
            really. A good choice of hop is the window length divided by the main lobe width 
            in freq. samples, which turns out to be just the inverse of the width."
            A lower hoptime can be used: for instance a 2x overlap would result in a hoptime
            of hoptime=1/windowsize*0.5
            **NB**: when using overlap, croptime should still be 1/windowsize
        freqdrift: Hz. The maximum variation of frecuency between two breakpoints to be
            considered to belong to the same partial. A sensible value is
            between 1/2 to 3/4 of resolution: freqdrift=0.62*resolution
        sidelobe: dB (default: 90 dB). A positive dB value, indicates the shape of the Kaiser window
        ampfloor: dB. A breakpoint with an amp < ampfloor can't be part of a partial
        croptime: sec. Max. time correction beyond which a reassigned bp is considered 
            unreliable, and not eligible. Default: the hop time. 
        residuebw: Hz (default = 2000 Hz). Construct Partial bandwidth env. by associating 
            residual energy with the selected spectral peaks that are used to construct Partials.
            The bandwidth is the width (in Hz) association regions used.
            Defaults to 2 kHz, corresponding to 1 kHz region center spacing.
            NB: if residuebw is set, convergencebw must be left unset
        convergencebw: range [0, 1]. Construct Partial bandwidth env. by storing the 
            mixed derivative of short-time phase, scaled and shifted.  
            The value is the amount of range over which the mixed derivative 
            indicator should be allowed to drift away from a pure sinusoid 
            before saturating. This range is mapped to bandwidth values on
            the range [0,1].  
            **NB**: one can set residuebw or convergencebw, but not both
    
    Returns:
        a list of numpy 2D arrays, where each array represents a partial. Any such array
        has a shape = (numrows, 5), where numrows is the number of breakpoints in the
        partial, each breakpoint consists of 5 values: time, freq, amplitude, phase and bandwidth

    """
    if windowsize < 0:
        windowsize = resolution * 2  # original Loris behaviour
    cdef loris.Analyzer* an = new loris.Analyzer(resolution, windowsize)
    if hoptime > 0:
        logger.debug("Setting hoptime for Analyzer: {0}".format(hoptime))
        an.setHopTime(hoptime)
    if freqdrift > 0:
        an.setFreqDrift(freqdrift)
    if sidelobe > 0:
        an.setSidelobeLevel( sidelobe )
    if croptime > 0:
        an.setCropTime( croptime )
    an.setAmpFloor(ampfloor)
    if residuebw >= 0:
        if convergencebw >= 0:
            logger.error("Only one of residuebw or convergencebw can be set, not both")
        an.storeResidueBandwidth(residuebw)
    elif convergencebw >= 0:
        an.storeConvergenceBandwidth(convergencebw)

    cdef int winSamples = kaiserWindowLength(an.windowWidth(), sr, an.sidelobeLevel())
    logger.info(f"analysis: windowsize={an.windowWidth()}Hz ({winSamples} samples), hop={int(an.hopTime()*1000)}ms, freqdrift={an.freqDrift()}Hz")

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


cdef double kaiserWindowShape(double atten):
    if atten > 60.0:
        alpha = 0.12438 * (atten + 6.3)
    elif atten > 13.26:
        alpha = 0.76609 * pow((atten - 13.26), 0.4) + 0.09834 * (atten - 13.26)
    else:   
        alpha = 0.0
    return alpha


cpdef int kaiserWindowLength(double width, double sr, double sidelobe) except -1:
    """
    Returns the window length (in samples) of a kaiser window with the
    given properties

    Args:
        width: the width of the window in Hz. 
        sr: the sample rate
        sidelobe: in possitive dB

    Returns:
        the length of the window in samples
    """
    # copyied from KaiserWindow for brevity
    if sidelobe < 0:
        raise ValueError("sidelobe should be a possitive dB value")
    cdef double normWidth = width / sr
    cdef double alpha = kaiserWindowShape(sidelobe)
    return int(1.0 + (2. * sqrt((pi*pi) + (alpha*alpha)) / (pi*normWidth)))


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
    cdef _np.ndarray [SAMPLE_t, ndim=2] arr = np.empty((numbps, 5), dtype='float64')
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

    
def read_sdif(path):
    """
    Read the SDIF file

    Args:
        sdiffile: (str) The path to a SDIF file

    Returns:
        a tuple(list of partials, labels), where a partial is a 2D numpy
        array with shape (num. breakpoints, 5) with the columns (time, 
        frequency, amplitude, phase and bandwidth). `labels` is list of 
        the labels for each partial
    """
    cdef loris.SdifFile* sdif
    cdef loris.PartialList partials
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.exists(path):
        raise FileNotFoundError(f"read_sdif: {path} not found")
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
    """
    This is a wrapper around a loris.PartialList
    """
    cdef loris.PartialList *thisptr
    
    def __dealloc__(self):
        PartialList_destroy(self.thisptr)
        
    def dump(self):
        """
        Dump the partials in this partial list
        """
        PartialList_dump(self.thisptr)

    def setlabels(self, labels):
        """
        Sets the labels in this partials list

        Args:
            labels (list[int]): It should be of the same length of 
                this partials list
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


cpdef PartialListW newPartialList(partials, labels=None, double fadetime=0):
    """
    Creates a new loris PartialList from the given data, and a PartialListW 
    (a wrapper) around that PartialList

    Args:
        partials: a list of numpy arrays, where each array represents a partial.
            Each partial is a 2D array of shape (num rows, 5) with columns
            (time, freq, amp, phase, bandwidth)
        labels: if given, a list of integers of the same length as partials
        fadetime: a fadetime applied to each partial when synthesizing
    """
    cdef loris.PartialList *plist = PartialList_fromdata(partials, fadetime)
    cdef PartialListW self = PartialListW()
    self.thisptr = plist
    if labels is not None:
        if isinstance(labels, int):
            labels = [labels] * len(self)
        self.setlabels(labels)
    return self


def _write_sdif(partials, outfile, labels=None, rbep=True, double fadetime=0):
    """
    Write a list of partials in the sdif 
    
    !!! note

        The 1TRC format forces resampling, since all breakpoints within a 
        1TRC frame need to share the same timestamp. In the RBEP format
        a breakpoint has a time offset to the frame time stamp
    
    Args:
        partials: a seq. of 2D arrays with columns [time freq amp phase bw]
        outfile: the path of the sdif file
        labels: a seq. of integer labels, or None to skip saving labels
        rbep: if True, use RBEP format, otherwise, 1TRC

    Returns:
        None

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

    !!! note

        Raises ValueError if the soundfile is not mono

    Args:
        path: (str) The path to the soundfile (.aif or .aiff)

    Returns:
        A tuple (audiodata, samplerate), where audiodata is a 1D numpy 
        array of type double, holding the samples
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
    mono = np.empty((numFrames,), dtype='float64')
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


def synthesize(partials, int samplerate, double fadetime=-1, double start=-1, double end=-1):
    """
    Synthesize the partials as audio

    Args:
        partials: a seq. of 2D matrices, each matrix represents a partial
            Each row is a breakpoint of the form [time freq amp phase bw]
        samplerate: the samplerate of the synthesized samples (Hz)
        fadetime: to avoid clicks, partials not ending in 0 amp should be faded
            If negative, a sensible default is used (currently about 3 ms). 
            A minimum fadetime is always applied, even if 0 is given.
        start: the start time of synthesis (-1 = start of data)
        end: the end time of synthesis (-1 = end of data) 
                    
    Returns:
        the synthesized samples, a numpy 1D array of doubles holding the samples
    """
    cdef int minfadesamps = 16
    cdef float minfade = float(minfadesamps) / samplerate
    if fadetime < 0:
        fadetime = 64.0 / samplerate
    else:
        # always have a fadetime of at least minfadesamps samples
        if fadetime < minfade:
            fadetime = minfade
            logger.debug("fadetime is too small. Using fadetime=%f (%d samples)" % (minfade, minfadesamps))
        fadetime = max(fadetime, 10.0 / samplerate)
    cdef list matrices = partials if isinstance(partials, list) else list(partials)
    cdef _np.ndarray [SAMPLE_t, ndim=2] m
    cdef double t0, t1, mt0, mt1
    if start < 0 or end <= 0:
        t1 = 0
        t0 = INFINITY
        for m in matrices:
            mt0 = m[0, 0]
            if mt0 < t0:
                t0 = mt0
            mt1 = m[m.shape[0]-1, 0]
            if mt1 > t1:
                t1 = mt1
        if start < 0:
            start = t0
        if end <= 0:
            end = t1

    cdef unsigned int numsamples = int((end + fadetime) * samplerate) + 2
    cdef vector[double] bufvector;
    bufvector.resize(numsamples)
    cdef int i = 0
    cdef loris.Synthesizer *synthesizer = new loris.Synthesizer(samplerate, bufvector, fadetime)
    cdef loris.Partial *lorispartial
    cdef double synth_t0 = INFINITY
    cdef double synth_t1 = 0
    cdef list errors = []
    cdef int numsynthesized = 0
    cdef int numrows
    for m in matrices:
        mt0 = m[0, 0]
        if mt0 < 0:
            errors.append("Partial with negative time found: %f" % mt0)
            continue
        numrows = m.shape[0]
        mt1 = m[numrows-1, 0]
        if mt0 >= start and mt1 <= end:
            if mt0 < synth_t0:
                synth_t0 = mt0
            if mt1 > synth_t1:
                synth_t1 = mt1
            lorispartial = newPartial_fromarray(m)
            if lorispartial != NULL:
                synthesizer.synthesize(lorispartial[0])
                numsynthesized += 1
                del lorispartial
    # cdef size_t synth_idx0 = int(synth_t0*samplerate)
    # cdef size_t synth_idx1 = int(synth_t1*samplerate) + 1
    cdef size_t startidx = int(start*samplerate)
    cdef size_t endidx = int(end*samplerate)
    cdef double[::1] buf = np.zeros((endidx-startidx,), dtype=float)
    cdef int j = 0
    if numsynthesized > 0:
        for i in range(startidx, endidx):
            buf[j] = bufvector[i]
            j += 1
    else:
        logger.info("No partials were synthesized")
    if len(errors) > 0:
        logger.error("Errors where found durint synthesis: " + "\n".join(errors))
    del synthesizer
    return np.asarray(buf)
    

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
    cdef double[:] freqs = np.zeros((numelements,), dtype='float64')
    cdef double[:] confs = np.zeros((numelements,), dtype='float64')
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


def estimatef0(partials, double minfreq, double maxfreq, double interval):
    """
    Estimate the fundamental as a curve in time. To each freq. value there 
    is a confidency value, where 1 represents maximum confidency, and values 
    below 0.9 indicate unvoiced or very faint sounds. 

    ## Example
    
    ```python

    import scipy.interpolate
    partials, labels = read_sdif("path/to/sdif")
    dt = 0.05  # estimate f0 at a 50 ms interval
    freqs, confidencies, t0, t1 = estimatef0(partials, 50, 2000, dt)
    freqs *= confidences > 0.9
    times = numpy.arange(t0, t1, dt)
    f0 = scipy.interpolate.interp1d(times, freqs)
    print(f0(0.8))
    
    ```

    Args:
        partials: a seq. of numpy 2D partials, each matrix representing a partial
        minfreq: min. freq to look for a fundamental
        maxfreq: max. freq to look for a fundamental
        interval: time resolution of the fundamental curve

    Returns:
        a tuple (freq, confidencies, start_time, end_time), where freqs is a
        numpy array holding the frequencies in time, confidencies is a numpy
        array with confidence values for each frequency measurement and start
        time and end time hold the start and end time of the measurements. 
        All times can be calculated via `numpy.arange(start_time, end_time, interval)
    
    """
    cdef loris.PartialList *pl = PartialList_fromdata(partials, 0)
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
    cdef double[::1] out = np.empty((numelements,), dtype='float64')
    while i < numelements:
        x = x0 + interval*i
        y = env.valueAt(x)
        out[i] = y
        i += 1
    return np.asarray(out)


def meancol(double[:,:] X, int col):
    """
    Calculate the mean over the given column.
    Similar to X[:,col].mean()
    """
    cdef double accum = 0
    cdef int i
    cdef int L = X.shape[0]
    for i in range(L):
        accum += X[i, col]
    return accum / L


def meancolw(double[:, :] X, int col, int colw):
    """
    Calculate the mean over `col` column, using col `colw` as weight
    """
    cdef double accum=0, weightsum=0
    cdef int i
    cdef int L = X.shape[0]
    cdef double x, w
    for i in range(L):
        x = X[i, col]
        w = X[i, colw]
        accum += x*w
        weightsum += w
    return accum / weightsum


cdef inline _np.ndarray EMPTY2D(int numrows, int numcols): 
    cdef _np.npy_intp *dims = [numrows, numcols]
    return _np.PyArray_EMPTY(2, dims, _np.NPY_DOUBLE, 0)


def _make_rbep_frame(double[:, :] bparray, int startidx, int endidx, double t0):
    """
    takes the columns between startidx and endidx (not inclusive) and fills 
    an array with the form
                          0     1    2   3     4  5 
    Original Columns:     time  freq amp phase bw index
    rbep frame:           index freq amp phase bw timeoffset
    """
    cdef: 
        int numrows
        int numcols
        int i
        int j

    numrows = bparray.shape[0]
    numcols = bparray.shape[1]

    cdef double[:,:] out = EMPTY2D(numrows, numcols)

    for i in range(endidx - startidx):
        j = startidx + i
        out[i, 0] = bparray[j, 5]
        out[i, 1] = bparray[j, 1]
        out[i, 2] = bparray[j, 2]
        out[i, 3] = bparray[j, 3]
        out[i, 4] = bparray[j, 4]
        out[i, 5] = bparray[j, 0] - t0

    return np.asarray(out)