import numpy as np
import numpyx as npx

# __all__ = [
#     "concat",
#     "partial_dur",
#     "partial_sample",
#     "partial_meanamp",
#     "partials_pack",
#     "partials_filter",
#     "matrix_save_as_wav"
# ]


def concat(partials, fade=0.010, edgefade=0):
    """
    Concatenate multiple Partials to produce a new one.
    Assumes that the partials are non-overlapping and sorted
    """
    # fade = max(fade, 128/48000.)
    numpartials = len(partials)
    if numpartials == 0:
        raise ValueError("No partials to concatenate")
    T, F, A, B = [], [], [], []
    eps = fade/4
    fade0 = fade
    fade = fade - 2*eps

    if edgefade > 0:
        p = partials[0]
        t0 = p[0, 0] - edgefade
        if t0 > 0:
            T.append([t0])
            F.append([p[0, 1]])
            A.append([0])
            B.append([0])
    
    if numpartials == 1:
        p = partials[0]
        T.append(p[:,0])
        F.append(p[:,1])
        A.append(p[:,2])
        B.append(p[:,4])
    else:
        for i in range(len(partials) - 1):
            p0 = partials[i]
            p1 = partials[i+1]
            assert p1[0, 0] - p0[-1, 0] > fade0*2
            T.append(p0[:,0])
            F.append(p0[:,1])
            A.append(p0[:,2])
            B.append(p0[:,4])
            if fade > 0:
                f0 = p0[-1, 1]
                f1 = p1[0, 1]
                t0 = p0[-1, 0]
                t1 = p1[0, 0]
                T.append([t0+fade,  t0+fade+eps,    t0+fade+eps+eps,    t1-fade])
                F.append([f0,       f0,             f1,                 f1])
                A.append([0,         0,              0,                 0])
                B.append([0, 0, 0, 0])
        T.append(p1[:,0])
        F.append(p1[:,1])
        A.append(p1[:,2]) 
        B.append(p1[:,4])
    
    if edgefade > 0:
        p = partials[-1]
        t1 = p[-1, 0]
        f1 = p[-1, 1]
        T.append([t1 + edgefade])
        F.append([f1])
        A.append([0])
        B.append([0])
    
    times = np.concatenate(T)
    freqs = np.concatenate(F)
    amps = np.concatenate(A)
    bws = np.concatenate(B)
    phases = np.zeros_like(bws)
    return np.column_stack((times, freqs, amps, phases, bws))


def _get_best_track(tracks, partial, gap, acceptabledist):
    """
    Get the best track minimizing gap
    """
    pt0 = partial[0, 0]
    mindist = float("inf")
    best = None
    for track in tracks:
        t1 = track[-1][-1, 0] + gap
        if t1 < pt0:
            dist = t1 - pt0
            if dist < acceptabledist:
                return track
            if dist < mindist:
                best = track
                mindist = dist
    return best

    
def partials_pack(partials, numtracks=0, gap=0.010, acceptabledist=0.100):
    """
    Pack non-simulatenous partials into longer partials with
    silences in between. These packed partials can be used
    as tracks for resynthesis, minimizing the need
    of oscillators. 

    partials: a list of arrays, where each array represents
              a partial, as returned by analyze
    
    numtracks: if > 0, sets the maximum number of tracks.
               Partials not fitting in will be discarded
    gap: minimum gap between partials in a track
    acceptabledist: instead of searching for the best possible
                    fit, pack two partials together if they are
                    near enough

    NB: amplitude is always faded out between partials
    """
    tracks = []
    fade = 0.008  # loris uses 5 ms
    gap = max(gap, fade*2)

    def join_track(partials, fade):
        assert fade > 0
        p = concat(partials, fade=fade, edgefade=fade)
        assert npx.array_is_sorted(p[:,0])
        assert p[0, 2] == 0
        assert p[-1, 2] == 0
        return p
    
    for partial in partials:
        best_track = _get_best_track(tracks, partial, gap, acceptabledist)
        if best_track is not None:
            best_track.append(partial)
        else:
            if numtracks == 0 or len(tracks) < numtracks:
                track = [partial]
                tracks.append(track)

    partials = [join_track(track, fade=fade) for track in tracks]
    return partials


def partials_sample(sp, dt=64/48000, t0=None, t1=None, interleave=True):
    # type: (Spectrum, float) -> Tuple[np.ndarray, np.ndarray, np.ndarray]
    """
    Samples the partials between t0 and t1. 

    Given ts = arange(t0, t1, dt)

    * If interleave is True, it returns a big matrix of format

    [[f0, amp0, bw0, f1, amp1, bw1, ..., fN, ampN, bwN],   # <--- ts[0]
     [f0, amp0, bw0, f1, amp1, bw1, ..., fN, ampN, bwN],   # <--- ts[1]
     ... 
    ]

    Where f0, amp0, bw0 represent the freq, amp and bw of partial 0 
    at a given time

    * If interleave is False, it returns three arrays: freqs, amps, bws
      of the form

    [[f0, f1, f2, ..., fn]  @ ts[0]
     [f0, f1, f2, ..., fn]  @ ts[1]
    ]
    
    In each array, the columns represent each partial, the rows are the
    value for each time.

    See also: save_matrix_as_wav

    """
    if t0 is None:
        t0 = min(p[0, 0] for p in sp)
    if t1 is None:
        t1 = max(p[-1, 0] for p in sp)
    times = np.arange(t0, t1+dt, dt)
    if not interleave:
        freqs, amps, bws = [], [], []
        for p in sp:
            out = partial_sample(p, times)
            freqs.append(out[:,0])
            amps.append(out[:,1])
            bws.append(out[:,3])
        freqarray = np.column_stack(freqs)
        amparray = np.column_stack(amps)
        bwarray = np.column_stack(bws)
        return freqarray, amparray, bwarray
    else:
        cols = []
        for p in sp:
            out = npx.table_interpol_linear(p, times)
            cols.append(out[:,(0, 1, 3)])
        return np.hstack(cols)


def partial_start(p):
    return p[0, 0]


def partial_dur(p):
    return p[-1, 0] - p[0, 0]


def partial_meanamp(p):
    # todo: Use the times to perform an integration rather than
    # just returning the mean of the amps
    return p[:,2].mean()


def _db2amp(x):
    return 10.0 ** (0.05 * x)


def partials_filter(ps, mindur=0.010, minamp=-70, maxfreq=24000, minfreq=0):
    """
    Return only those partials which have a min. duration of at least
    `mindur`, an avg. amplitude of at least `minamp` and a freq. between
    `minfreq` and `maxfreq`
    """
    amp = _db2amp(minamp)
    out = []
    for p in ps:
        if partial_dur(p) < mindur:
            continue
        f0, f1 = npx.minmax1d(p[:,1])
        if minamp > f0 or f1 > maxfreq:
            continue
        if partial_meanamp(p) < amp:
            continue
        out.append(p)
    return out


def partial_sample(p, ts):
    """
    Sample partial p at times ts (with linear interpolation)
    """
    return npx.table_interpol_linear(p, ts)


def matrix_save_as_sndfile(m, sndfile, dt, t0=0, bits=32):
    """
    Save the data in m as a float32 soundfile. This is not a real soundfile
    but it is used to transfer the data in binary form to be 
    read in another application. Supported formats are "wav" and "aiff"

    A header is included with the format

    [dataOffset, dt, numcols, numrows, t0]

    The data `m` is a 2D numpy array. It is written as a flat array after
    the header

    Example:

    tracks = partials_pack(partials)
    dt = 64/44100
    m = partials_sample(tracks, dt)
    numrows, numcols = m.shape
    matrix_save_as_sndfile(m, dt, "out.wav")
    
    sndfile: the extension will determine the soundfile generatad. 
             Only formats which support float samples are supported,
             which limits the possibilities to "wav" and "aif" files
    m: a 2D matrix representing a series of streams sampled at a 
       regular period (dt)
    dt: the sampling period which was used to produce m. 
        It is included in the header and is useful to make sense
        of the data when used in a different application
    t0: the start time of the sampling. The time grid used for the
        sampling can then be reconstructed as:

        times = np.arange(t0, t0+dt*numrows, dt)
    bits: 32 or 64. Both wav and aiff support 32 and 64 bit floats,
          and all applications using libsndfile will support this also,
          but many applications which use 32 bit floats for sound processing
          will discard the extra precission. 

    Applications which can make use of this data include csound (via its opcode
    adsynt2)
    """
    import pysndfile
    import os
    ext = os.path.splitext(sndfile)[1][1:][:3].lower()
    assert ext in ('wav', 'aif')
    assert bits in (32, 64)
    encoding = "float%d" % bits
    fmt = pysndfile.construct_format(ext, encoding)
    f = pysndfile.PySndfile(sndfile, mode="w", format=fmt, channels=1, samplerate=44100)
    numrows, numcols = m.shape
    header_array = np.array([5, dt, numcols, numrows, t0], dtype=float)
    f.write_frames(header_array)
    mflat = m.ravel()
    f.write_frames(mflat)


def partials_save_as_sndfile(partials, dt, outfile, bits=32):
    """
    A convenience function merging `partials_sample` and
    `matrix_save_as_sndfile`.

    * Partials are sampled at a regular interval of `dt`
    * They are saved as a 32-bit float soundfile for portability

    Assumes that partials hace been packed with `partials_pack`
    
    partials: a list of numpy arrays, where each array represents
              a partial, as returned by `analyze` or `read_sdif`

    dt: the sampling *PERIOD*. 
    outfile: the extension will determine the soundfile generatad. 
             Only formats which support float samples are supported,
             which limits the possibilities to "wav" and "aif" files
    """
    m = partials_sample(partials, dt=dt)
    t0 = min(p[0, 0] for p in partials)
    matrix_save_as_sndfile(m, outfile, dt=dt, t0=t0, bits=bits)
