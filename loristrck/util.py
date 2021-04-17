"""
Utility functions to manipulate / transform partials and list of partials

## Example 1

Select a group of partials and render the selection as sound

```python

import loristrck as lt
partials = lt.read_sdif(...)
selected, _ = lt.util.select(partials, minbps=2, mindur=0.005, 
                             minamp=-80, maxfreq=17000)
lt.util.patials_render(partials, 44100, "selected.wav")

```

"""
from __future__ import annotations
import os
import numpy as np
import numpyx as npx
import soundfile
import logging
import math
from typing import Tuple, Union as U, List, Optional as Opt
import sys

from . import _core

logger = logging.getLogger("loristrck")

__all__ = [
    "concat",
    "partial_at",
    "partial_crop",
    "partials_sample",
    "meanamp",
    "meanfreq",
    "partial_energy",
    "select",
    "filter",
    "sndreadmono",
    "sndwrite",
    "plot_partials",
    "kaiser_length",
    "partials_stretch",
    "partials_transpose",
    "partials_between",
    "partials_at",
    "partials_render",
    "estimate_sampling_interval",
    "pack",
    "partials_save_matrix",
   
]


def concat(partials: List[np.ndarray], fade=0.005, edgefade=0.) -> np.ndarray:
    """
    Concatenate multiple Partials to produce a new one.
    
    Assumes that the partials are non-overlapping and sorted

    !!! note

        partials need to be non-simultaneous and sorted
    
    Args:
        partials: a seq. of partials (each partial is a 2D-array)
        fade: fadetime to apply at the end/beginning of each concatenated partial
        edgefade: a fade to apply at the beginning of the first and at
                  the end of the last partial

    Returns:
        a numpy array representing the concatenation of the given partials

    """
    # fade = max(fade, 128/48000.)
    numpartials = len(partials)
    if numpartials == 0:
        raise ValueError("No partials to concatenate")
    T, F, A, B = [], [], [], []
    eps = 0.000001
    fade0 = fade
    fade = fade-2*eps
    zeros4 = np.zeros((4,), dtype=float)
    zeros1 = np.zeros((1,), dtype=float)

    if edgefade > 0:
        p = partials[0]
        p00 = p[0, 0]
        t0 = p00-edgefade
        if t0 > 0:
            T.append([t0])
            F.append([p[0, 1]])
            A.append([0])
            B.append([0])
        elif p00 > 0:
            T.append([0])
            F.append([p[0, 1]])
            A.append([0])
            B.append([0])

    if numpartials == 1:
        p = partials[0]
        T.append(p[:, 0])
        F.append(p[:, 1])
        A.append(p[:, 2])
        B.append(p[:, 4])
    else:
        for i in range(len(partials)-1):
            p0 = partials[i]
            p1 = partials[i+1]
            if p1[0, 0]-p0[-1, 0] < fade0*2:
                raise ValueError("Partials overlap, can't concatenate")
            T.append(p0[:, 0])
            F.append(p0[:, 1])
            A.append(p0[:, 2])
            B.append(p0[:, 4])
            if fade > 0:
                f0 = p0[-1, 1]
                f1 = p1[0, 1]
                t0 = p0[-1, 0]
                t1 = p1[0, 0]
                tmid = (t0+t1)*0.5
                T.append([t0+fade, tmid-eps, tmid+eps, t1-fade])
                F.append([f0, f0, f1, f1])
                A.append(zeros4)
                B.append(zeros4)
        p1 = partials[-1]
        T.append(p1[:, 0])
        F.append(p1[:, 1])
        A.append(p1[:, 2])
        B.append(p1[:, 4])

    p = partials[-1]
    if p[-1, 2] > 0 and edgefade > 0:
        t1 = p[-1, 0]
        f1 = p[-1, 1]
        T.append([t1+edgefade])
        F.append([f1])
        A.append(zeros1)
        B.append(zeros1)

    times = np.concatenate(T)
    freqs = np.concatenate(F)
    amps = np.concatenate(A)
    bws = np.concatenate(B)
    phases = np.zeros_like(bws)
    return np.column_stack((times, freqs, amps, phases, bws))


def _get_best_track(tracks: List[list], partial: np.ndarray, gap: float,
                    acceptabledist: float
                    ) -> List[np.ndarray]:
    """
    Get the best track minimizing gap

    Args:
        tracks: a list of tracks, where each track is a list of partials
            (a partial is a numpy array)
        partial: the partial to fit (a numpy array)
        gap: the min. time gap between any two partials in a track
        acceptabledist: an acceptable time distance between a partial in a track and 
            a new partial 
    """
    pt0 = partial[0, 0]
    mindist = float("inf")
    best = None
    for track in tracks:
        t1 = track[-1][-1, 0]+gap
        if t1 < pt0:
            dist = t1-pt0
            if dist < acceptabledist:
                return track
            if dist < mindist:
                best = track
                mindist = dist
    return best


def _join_track(partials: List[np.ndarray], fade: float) -> np.ndarray:
    """
    Join the (non simultaneous) partials into one partial

    Args:
        partials: a list of non-overlapping partials
        fade: a fadetime to apply to the partials

    Returns:
        a numpy array representing a track. A track is similar to a partial
        but multiple non-simulatenous partials are concatenated and faded out,
        leaving gaps of silence in between
    """
    assert fade > 0, f"fade should be > 0, got {fade}"
    p = concat(partials, fade=fade, edgefade=fade)
    assert p[-1, 2] == 0, f"concat failed to fade-out, last amp = {p[-1, 2]}"
    return p


def pack(partials: List[np.ndarray],
         maxtracks: int = 0,
         gap=0.010,
         fade=-1.,
         acceptabledist=0.100,
         minbps: int = 2) -> Tuple[List[np.ndarray], List[np.ndarray]]:
    """
    Pack non-simultenous partials into longer partials with silences in between. 

    These packed partials can be used as tracks for resynthesis, minimizing the need
    of oscillators.

    !!! note
    
        Amplitude is always faded out between partials

    **See also**: [partials_save_matrix](util.md#partials_save_matrix)
    
    Args:
        partials: a list of arrays, where each array represents a partial,
            as returned by analyze
        maxtracks: if > 0, sets the maximum number of tracks. Partials not
            fitting in will be discarded. Consider living this at 0, to allow
            for unlimited tracks, and limit the amount of active streams later
            on
        gap: minimum gap between partials in a track. Should be longer than
            2 times the sampling interval, if the packed partials are later
            going to be resampled.
        fade: apply a fade to the partials before joining them.
            If not given, a default value is calculated
        acceptabledist: instead of searching for the best possible fit, pack 
            two partials together if they are near enough
        minbps: the min. number of breakpoints for a partial to the packed. Partials
            with less that this number of breakpoints are filtered out

    Returns:
        a tuple (tracks, unpacked partials)

    """
    assert all(isinstance(p, np.ndarray) for p in partials)
    mingap = 0.010
    if gap < mingap:
        gap = mingap
        logger.info(f"pack: gap value is too small. Using default: {gap}")
    if fade < 0:
        fade = min(0.005, gap/3.0)
        logger.debug(f"pack: using fade={fade}")
    clearance = gap+2*fade

    def _pack_partials(partials, tracks=None):
        tracks = tracks if tracks is not None else []
        unpacked = []
        for partial in partials:
            if len(partial) < minbps:
                continue
            best_track = _get_best_track(tracks, partial, clearance,
                                         acceptabledist)
            if best_track is not None:
                best_track.append(partial)
            else:
                if maxtracks == 0 or len(tracks) < maxtracks:
                    track = [partial]
                    tracks.append(track)
                else:
                    unpacked.append(partial)
        return tracks, unpacked

    tracks, unpacked = _pack_partials(partials)
    joint_tracks = [_join_track(track, fade=fade) for track in tracks]
    return joint_tracks, unpacked


def partial_sample_regularly(p: np.ndarray, dt: float, t0=-1., t1=-1.) -> np.ndarray:
    """
    Sample a partial `p` at regular time intervals

    Args:
        p: a partial represented as a 2D-array with columns 
            `times, freqs, amps, phases, bws`
        dt: sampling period
        t0: start time of sampling
        t1: end time of sampling

    Returns:
        a partial (2D-array with columns times, freqs, amps, phases, bws)
    """
    if t0 < 0:
        t0 = p[0, 0]
    if t1 <= 0:
        t1 = p[-1, 0]
    times = np.arange(t0, t1+dt, t1)
    return partial_sample_at(p, times)


def partial_sample_at(p: np.ndarray, times: np.ndarray) -> np.ndarray:
    """
    Sample a partial `p` at given times

    Args:
        p: a partial represented as a 2D-array with columns
           times, freqs, amps, phases, bws
        times: the times to evaluate partial at

    Returns:
        a partial (2D-array with columns times, freqs, amps, phases, bws)
    """
    assert isinstance(times, np.ndarray)
    t0 = p[0, 0]
    t1 = p[-1, 0]
    index0 = npx.searchsorted1(times, t0)
    index1 = npx.searchsorted1(times, t1)-1
    times = times[index0:index1]
    data = npx.table_interpol_linear(p, times)
    timescol = times.reshape((times.shape[0], 1))
    return np.hstack((timescol, data))


def partial_at(p: np.ndarray, t: float, extend=False) -> Opt[np.ndarray]:
    """
    Evaluates partial `p` at time `t`

    Args:
        p: the partial, a 2D numpy array
        t: the time to evaluate the partial at
        extend: should the partial be extended to -inf, +inf? If True, querying a partial
            outside its boundaries will result in the values at the boundaries.
            Otherwise, None is returned

    Returns:
        the breakpoint at t (a np array of shape (4,) with columns (time, freq, amp, bw).
        Returns None if the array is not defined at the given time
    """
    if extend:
        bp = npx.table_interpol_linear(p, np.array([t], dtype=float))
    else:
        t0, t1 = p[0, 0], p[-1, 0]
        if t0 <= t <= t1:
            bp = npx.table_interpol_linear(p, np.array([t], dtype=float))
        else:
            return None
    bp.shape = (4,)
    return bp


def _open_with_standard_app(path: str) -> None:
    """
    Open path with the app defined to handle it by the user
    at the os level (xdg-open in linux, start in win, open in osx)

    In Linux and macOS this opens the default application in the background
    and returns immediately
    """
    import subprocess
    platform = sys.platform
    if platform == 'linux':
        subprocess.call(["xdg-open", path])
    elif platform == "win32":
        os.startfile(path)
    elif platform == "darwin":
        subprocess.call(["open", path])
    else:
        raise RuntimeError(f"platform {platform} not supported")


def partial_crop(p: np.ndarray, t0: float, t1: float) -> np.ndarray:
    """
    Crop partial at times t0, t1
    
    Args:
        p: the partial
        t0: the start time
        t1: the end time

    Returns:
        the cropped partial (raises `ValueError`) if the partial is not defined
        within the given time constraints)

    !!! note
    
        * Returns p if p is included in the interval t0-t1
        * Returns None if partial is not defined between t0-t1
        * Otherwise crops the partial at t0 and t1, places a breakpoint
          at that time with the interpolated value
    
    """
    times = p[:, 0]
    pt0 = times[0]
    pt1 = times[-1]
    if pt0 > t0 and pt1 < t1:
        return p
    if t0 > pt1 or t1 < pt0:
        raise ValueError(f"Partial is not defined between {t0} and {t1}")
    idxs = times > t0
    idxs *= times < t1
    databetween = p[idxs]
    arrays = []
    if t0 < databetween[0, 0] and t0 > pt0:
        arrays.append(partial_sample_at(p, [t0]))
    arrays.append(databetween)
    if t1 > databetween[-1, 0] and t1 < pt1:
        arrays.append(partial_sample_at(p, [t1]))
    return np.vstack(arrays)


def partials_sample(partials: List[np.ndarray], dt=0.002, t0: float = -1, t1: float = -1,
                    maxactive=0, interleave=True):
    """
    Samples the partials between times `t0` and `t1` with a sampling period `dt`

    Args:
        partials: a list of 2D-arrays, each representing a partial
        dt: sampling period
        t0: start time, or None to use the start time of the spectrum
        t1: end time, or None to use the end time of the spectrum
        maxactive: limit the number of active partials to this number. If the
            number of active streams (partials with non-zero amplitude) is
            higher than `maxactive`, the softest partials will be zeroed.
            During resynthesis, zeroed partials are skipped.
            This strategy is followed to allow to pack all partials at the cost
            of having a great amount of streams, and limit the streams (for
            better performance) at the synthesis stage.
        interleave: if True, all columns of each partial are interleaved
                    (see below)

    Returns:
        if interleave is True, returns a big matrix where all partials are interleaved
        and present at all times. Otherwise returns three arrays, (freqs, amps, bws)
        where freqs represents the frequencies of all partials, etc. See below

    To be used in connection with `pack`, which packs short non-simultaneous
    partials into longer ones. The result is a 2D matrix representing the partials.

    Sampling times is calculated as: `times = arange(t0, t1+dt, dt)`

    If interleave is True, it returns a big matrix of format

    ```python

    [[t0, f0, amp0, bw0, f1, amp1, bw1, …, fN, ampN, bwN],
     [t1, f0, amp0, bw0, f1, amp1, bw1, …, fN, ampN, bwN],
     ...
    ]
    ```

    Where (f0, amp0, bw0) represent the freq, amplitude and bandwidth
    of partial 0 at a given time, `(f1, amp1, bw0)` the corresponding data
    for partial 1, etc.

    If interleave is False, it returns three arrays: freqs, amps, bws
    of the form:

    ```python        

        [[f0, f1, f2, ..., fn]  # at times[0]
         [f0, f1, f2, ..., fn]  # at times[1]
        ]
    ```
    
    !!! note

        phase information is not sampled

    """
    if t0 < 0:
        t0 = min(p[0, 0] for p in partials)
    if t1 <= 0:
        t1 = max(p[-1, 0] for p in partials)
    times = np.arange(t0, t1+dt, dt)
    if not interleave:
        freqs, amps, bws = [], [], []
        for p in partials:
            out = npx.table_interpol_linear(p, times)
            freqs.append(out[:, 0])
            amps.append(out[:, 1])
            bws.append(out[:, 3])
        freqarray = np.column_stack(freqs)
        amparray = np.column_stack(amps)
        bwarray = np.column_stack(bws)
        if maxactive > 0:
            _limit_matrix(amparray, maxactive)
        return freqarray, amparray, bwarray
    else:
        cols = [times]
        for p in partials:
            p_resampled = npx.table_interpol_linear(p, times)
            # Extract columns: freq, amp, bw (freq is now index 0, because
            # the resampled partial has no times column)
            cols.append(p_resampled[:, (0, 1, 3)])
        m = np.hstack(cols)
        if maxactive > 0:
            _limit_matrix_interleaved(m, maxactive)
        return m


def _limit_matrix(m, maxstreams):
    for i in range(len(m)):
        amps = m[i]
        idxs = np.argsort(amps)[:-maxstreams]
        m[idxs] = 0


def _limit_matrix_interleaved(m, maxstreams):
    numrows = m.shape[0]
    for i in range(numrows):
        amps = m[i, 1::3]
        idxs = np.argsort(amps)[:-maxstreams]
        amps[idxs] = 0


def meanamp(partial: np.ndarray) -> float:
    """
    Returns the mean amplitude of a partial

    Args:
        partial: a numpy 2D-array representing a Partial
    
    Returns:
        the average amplitude
    """
    # todo: Use the times to perform an integration rather than
    # just returning the mean of the amps
    return _core.meancol(partial, 2)


def meanfreq(partial: np.ndarray, weighted=False) -> float:
    """
    Returns the mean frequency of a partial, optionally
    weighting this mean by the amplitude of each breakpoint
    """
    if not weighted:
        return _core.meancol(partial, 1)
    return _core.meancolw(partial, 1, 2)


def partial_energy(partial: np.ndarray) -> float:
    """
    Integrate the partial amplitude over time. Serves as measurement
    for the energy contributed by the partial.

    ### Example

    Select loudest partials within the range 50 Hz - 6000 Hz

    ```python

    import loristrck as lt
    partials = lt.read_sdif("path.sdif")
    partials2 = lt.util.select(partials, minfreq=50, maxfreq=6000, 
                               minbps=4, mindur=0.005)
    sorted_partials = sorted(partials2, key=lt.util.partial_energy, reverse=True)
    loudest = sorted_partials[:100]
    lt.util.plot_partials(loudest)
    ```
    """
    dur = partial[-1, 0]-partial[0, 0]
    return meanamp(partial)*dur


def db2amp(x: float) -> float:
    """
    Convert amplitude in dB to linear amplitude
    """
    return 10.0**(0.05*x)


def db2ampnp(x: np.ndarray) -> np.ndarray:
    """
    Convert amplitude in dB to linear amplitude for a numpy array
    """
    return 10.0**(0.05*x)


def select(partials: List[np.ndarray], mindur=0., minamp=-120, maxfreq=24000,
           minfreq=0, minbps=1, t0=0., t1=0.
           ) -> Tuple[List[np.ndarray], List[np.ndarray]]:
    """
    Selects a seq. of partials matching the given conditions

    Select only those partials which have
        
    * a min. duration of at least `mindur` AND
    * an avg. amplitude of at least `minamp` AND
    * a freq. between `minfreq` and `maxfreq` AND
    * have at least `minbps` breakpoints

    ### Example

    ```python

    import loristrck as lt
    partials = lt.read_sdif(...)
    selected, _ = lt.util.select(partials, minbps=2, mindur=0.005, 
                                 minamp=-80, maxfreq=17000)
    ```
    
    Args:
        partials: a list of numpy 2D arrays, each array representing a partial
        mindur: min. duration (in seconds)
        minamp: min. amplitude (in dB)
        maxfreq: max. frequency
        minfreq: min. frequency
        minbps: min. breakpoints
        t0: only partials defined after t0
        t1: only partials defined before t1

    Returns: 
        (selected partials, discarded partials)

    """
    amp = db2amp(minamp)
    selected = []
    unselected = []
    checkfreq = minfreq > 0 or maxfreq < 24000
    checkbps = minbps > 1 or mindur > 0
    checktime = t0 > 0 or t1 > 0
    for p in partials:
        if checktime:
            if p[-1, 0] < t0 or (t1 > 0 and p[0, 0] > t1):
                continue
        if checkbps and (len(p) < minbps or (p[-1, 0]-p[0, 0]) < mindur):
            unselected.append(p)
            continue
        if checkfreq:
            f0, f1 = npx.minmax1d(p[:, 1])
            if minfreq > f0 or f1 > maxfreq:
                unselected.append(p)
                continue
        if minamp > -120:
            if meanamp(p) < amp:
                unselected.append(p)
                continue
        selected.append(p)
    return selected, unselected


def filter(partials: List[np.ndarray], mindur=0., mindb=-120, maxfreq=2400,
           minfreq=0, minbps=1, t0=0., t1=0.):
    """
    Similar to select, but returns a generator yielding only selected partials
    """
    amp = db2amp(mindb)
    checkfreq = minfreq > 0 or maxfreq < 24000
    checkbps = minbps > 1 or mindur > 0
    checktime = t0 > 0 or t1 > 0
    for p in partials:
        if checktime:
            if p[-1, 0] < t0 or (t1 > 0 and p[0, 0] > t1):
                continue
        if checkbps and (len(p) < minbps or (p[-1, 0]-p[0, 0]) < mindur):
            continue
        if checkfreq:
            f = _core.meancol(p, 1)
            if not (minfreq<=f<=maxfreq):
                continue
        if mindb > -120:
            if meanamp(p) < amp:
                continue
        yield p


def loudest(partials: List[np.ndarray], N: int = 0) -> List[np.ndarray]:
    """
    Get the loudest N partials. If N is not given, all partials
    are returned, sorted in declining energy

    The returned partials will be sorted by declining energy
    (integrated amplitude)
    """
    sorted_partials = sorted(partials, key=partial_energy, reverse=True)
    if N:
        sorted_partials = sorted_partials[:N]
    return sorted_partials


def matrix_save(data: np.ndarray, outfile: str, bits=32, header=True, metadata=True
                ) -> None:
    """
    Save the raw data mtx.

    The data is saved either as a `.mtx` or as a `.npy` file.

    !!! note: file format

    The `mtx` is an ad-hoc format where a .wav format is used to store binary
    data. This .wav file is not a real soundfile but it turns out that the .wav format
    is very useful for saving binary data (it is endiannes independent,
    it supports some limited metadata and is widely supported)

    The `.npy` format is defined by numpy here:
    <https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html#module-numpy
    .lib.format>

    Args:
        data: a 2D-matrix as returned by `partials_sample`
        outfile: the path to the resulting output file. The format should be
            .wav or .npy
        bits: 32 or 64. 32 bits should be enough
        header: if True, a header is included with the format `[dataOffset, numcols,
            numrows]`
        metadata: If True, metadata is included which duplicates the
            data of the header in string form.

    The data `mt` is a 2D numpy array. It is written as a flat array after
    the header

    ### Example

    ```python
    
        import loristrck as lt
        partials = lt.read_sdif(path_to_sdif)
        tracks = lt.pack(partials)
        dt = 64/44100
        m = lt.partials_sample(tracks, dt)
        matrix_save(m, "out.wav")
    ```
    """
    fmt = os.path.splitext(outfile)[1]
    if fmt == '.mtx':
        f = _wavwriter(outfile, sr=44100, bits=bits)
        numrows, numcols = data.shape
        if metadata:
            metastr = b"HeaderLength=%d, NumCols=%d, NumRows=%d"%(2, numcols, numrows)
            f.comment = metastr
            f.software = "loristrck"
        if header:
            header_array = np.array([2, numcols, numrows], dtype=float)
            f.write(header_array)
        mflat = data.ravel()
        f.write(mflat)
        f.close()
    elif fmt == '.npy':
        np.save(outfile, data, allow_pickle=False)
    else:
        raise ValueError(f"Format {fmt} not recognized")


def _wavwriter(outfile, sr=44100, bits=32, channels=1):
    assert bits in (32, 64)
    ext = os.path.splitext(outfile)[1][1:][:3].lower()
    assert ext in ('wav', 'aif')
    subtype = 'FLOAT' if bits == 32 else 'DOUBLE'
    return soundfile.SoundFile(outfile, mode="w", samplerate=sr, channels=channels,
                               subtype=subtype)


def wavwrite(outfile, samples, sr=44100, bits=32):
    """
    Write samples to a wav-file (see also sndwrite) as float32 or float64
    """
    f = _wavwriter(outfile, sr=sr, bits=bits, channels=_numchannels(samples))
    f.write(samples)
    f.close()


def partials_save_matrix(partials: List[np.ndarray], outfile: str, dt: float = None,
                         gapfactor=3., maxtracks=0, maxactive=0
                         ) -> Tuple[List[np.ndarray], np.ndarray]:
    """
    Packs short partials into longer partials and saves the result as a matrix

    ### Example
    
    ```python
    
    import loristrck as lt
    partials, labels = lt.read_sdif(sdiffile)
    selected, rest = lt.util.select(partials, minbps=2, mindur=0.005, minamp=-80)
    lt.util.partials_save_matrix(selected, 0.002, "packed.wav")

    ```
    
    Args:
        partials: a list of numpy 2D-arrays, each representing a partial
        dt: sampling period to sample the packed partials. If not given,
            it will be estimated with sensible defaults. To have more control
            over this stage, you can call estimate_sampling_interval yourself.
            At the cost of oversampling, a good value can be ksmps/sr, which results
            in 64/44100 = 0.0014 secs for typical values
        outfile: path to save the sampled partials. Supported formats: `.mtx`, `.npy`
            (See matrix_save for more information)
        gapfactor: partials are packed with a gap = dt * gapfactor.
            It should be at least 2. A gap is a minimal amount of silence
            between the partials to allow for a fade out and fade in
        maxtracks: Partials are packed in tracks and represented as a 2D matrix where
            each track is a row. If filesize and save/load time are a concern,
            a max. value for the amount of tracks can be given here, with the
            consequence that partials might be left out if there are no available
            tracks to pack them into. See also `maxactive`
        maxactive: Partials are packed in simultaneous tracks, which correspond to
            an oscillator bank for resynthesis. If maxactive is given,
            a max. of `maxactive` is allowed, and the softer partials are
            zeroed to signal that they can be skipped during resynthesis.

    Returns:
        a tuple (packed spectrum, matrix)

    """
    if dt is None:
        dt = estimate_sampling_interval(partials)
    assert all(isinstance(p, np.ndarray) for p in partials)
    tracks, rest = pack(partials, gap=dt*gapfactor, maxtracks=maxtracks)
    mtx = partials_sample(tracks, dt=dt, maxactive=maxactive)
    matrix_save(mtx, outfile, bits=32)
    return tracks, mtx


def _numchannels(samples: np.ndarray) -> int:
    return 1 if samples.ndim == 1 else samples.shape[1]


def sndreadmono(path: str, chan: int = 0, contiguous=True
                ) -> Tuple[np.ndarray, int]:
    """
    Read a sound file as mono. If the soundfile is multichannel,
    the indicated channel `chan` is returned.

    Args:
        path: The path to the soundfile
        chan: The channel to return if the file is multichannel
        contiguous: If True, it is ensured that the returned array 
            is contiguous. This should be set to True if the samples are to be
            passed to `analyze`, which expects a contiguous array

    Returns:
        a tuple (samples:np.ndarray, sr:int)
    """
    samples, sr = soundfile.read(path)
    if _numchannels(samples) > 1:
        samples = samples[:, chan]
    if contiguous:
        samples = np.ascontiguousarray(samples)
    return samples, sr


def sndwrite(samples: np.ndarray, sr: int, path: str, encoding: str = None) -> None:
    """
    Write the samples to a soundfile

    Args:
        samples: the samples to write
        sr: samplerate
        path: the outfile to write the samples to (the extension will determine the format)
        encoding: the encoding of the samples. If None, a default is used, according to
            the extension of the outfile given. Otherwise, a string 'floatXX' or 'pcmXX'
            is expected, where XX represent the bits per sample (15, 24, 32, 64 for pcm,
            32 or 64 for float). Not all encodings are supported by all formats.
    """
    if isinstance(encoding, str):
        encoding = encoding[:-2], int(encoding[-2:])
    elif encoding is None:
        ext = os.path.splitext(path)[1].lower()
        encoding = {
            '.wav':'float32',
            '.aif':'float32',
            '.aiff':'float32',
            '.flac':'pcm24'
        }.get(ext)
        if encoding is None:
            raise ValueError(f"format {ext} not supported")

    subtype = {
        'float32':'FLOAT',
        'float64':'DOUBLE',
        'pcm16':'PCM_16',
        'pcm24':'PCM_24',
        'pcm32':'PCM_32',
    }.get(encoding)

    if subtype is None:
        raise ValueError(f"encoding {encoding} not supported")

    f = soundfile.SoundFile(path,
                            mode="w",
                            samplerate=sr,
                            channels=_numchannels(samples),
                            subtype=subtype)
    f.write(samples)
    f.close()


def plot_partials(partials: List[np.ndarray], downsample: int = 1,
                  cmap='inferno', exp=1.0, linewidth=1, ax=None, avg=True
                  ):
    """
    Plot the partials using matplotlib

    Args:
        partials: a list of numpy arrays, each representing a partial
        downsample: If > 1, only one every `downsample` breakpoints will be taken
            into account.
        cmap: a string defining the colormap used
            (see <https://matplotlib.org/users/colormaps.html>)
        exp: an exponential to apply to the amplitudes before plotting
        linewidth: the line width of the plot
        avg: if True, the colour of a segment depends on the average between the
            amplitude at the start breakpoint and the end breakpoint of the segment
            Otherwise only the amplitude of the start breakpoint is used
        ax: A matplotlib axes. If one is passed, plotting will be done to this
            axes. Otherwise a new axes is created

    Returns:
        a matplotlib axes
    """
    from . import plot
    return plot.plot_partials(partials,
                              downsample=downsample,
                              cmap=cmap,
                              exp=exp,
                              linewidth=linewidth,
                              ax=ax)


def _kaiser_shape(atten):
    """
    atten: sidelobe attenuation, in possitive dB
    """
    if atten < 0.:
        raise ValueError(
                "Kaiser window shape must be computed from positive (> 0dB)"
                " sidelobe attenuation. (received attenuation < 0)")
    if atten > 60.0:
        alpha = 0.12438*(atten+6.3)
    elif atten > 13.26:
        alpha = (0.76609*math.pow(
                (atten-13.26), 0.4)+0.09834*(atten-13.26))
    else:
        # can't have less than 13dB.
        alpha = 0.0
    return alpha


def kaiser_length(width: float, sr: int, atten: int) -> int:
    """
    Returns the length in samples of a Kaiser window from the desired main lobe width.

    !!! note
    
        computeLength

        Compute the length (in samples) of the Kaiser window from the desired
        (approximate) main lobe width and the control parameter. Of course, since
        the window must be an integer number of samples in length, your actual
        lobal mileage may vary. This equation appears in Kaiser and Schafer 1980
        (on the use of the I0 window class for spectral analysis) as Equation 9.
        The main width of the main lobe must be normalized by the sample rate,
        that is, it is a fraction of the sample rate.

    Args:
        width: the width of the main lobe in Hz
        sr: the sample rate, in samples / sec
        atten: the attenuation in possitive dB

    Returns:
        the length of the window, in samples

    """
    norm_width = width/sr
    alpha = _kaiser_shape(atten)
    # the last 0.5 is cheap rounding. But I think I don't need cheap rounding
    # because the equation from Kaiser and Schafer has a +1 that appears to be
    # a cheap ceiling function.
    pi = math.pi
    return int(1.0+(2.*math.sqrt((pi*pi)+(alpha*alpha))/
                    (pi*norm_width)))


def _partial_estimate_breakpoint_gap(partial, percentile=50):
    times = partial[:, 0]
    diffs = times[1:]-times[:-1]
    gap = np.percentile(diffs, percentile)
    return gap


def _estimate_breakpoint_gap(partials, percentile, partial_percentile):
    """
    Estimate the breakpoint gap in this partials.
    """
    values = [
        _partial_estimate_breakpoint_gap(p, partial_percentile)
        for p in partials if len(p) > 2
    ]
    value = np.percentile(values, percentile)
    return value


def estimate_sampling_interval(partials: List[np.ndarray],
                               maxpartials=0,
                               percentile=25,
                               ksmps=64,
                               sr=44100) -> float:
    """
    Estimate a sampling interval (dt) for this spectrum

    The usage is to find a sampling interval which neither oversamples
    nor undersamples the partials for a synthesis strategy based on blocks of
    computation (like in csound, supercollider, etc, where each ugen is given
    a buffer of samples to fill instead of working sample by sample)

    Args:
        partials: a list of partials
        maxpartials: if given, only consider this number of partials to calculate dt
        percentile: ???
        ksmps: samples per cycle used when rendering. This is used in the estimation
            to prevent oversampling
        sr: the sample rate used for playback, used together with ksmps to estimate
            a useful sampling interval

    Returns:
        the most appropriate sampling interval for the data and the playback conditions
    """
    partial_percentile = percentile
    if maxpartials > 0:
        partials = partials[:maxpartials]
    gap = _estimate_breakpoint_gap(partials,
                                   percentile=percentile,
                                   partial_percentile=partial_percentile)
    kr = ksmps/sr
    dt = max(gap, kr)
    return round(dt, 4)


def partial_timerange(partial: np.ndarray) -> Tuple[float, float]:
    """
    Return begin and endtime of partial
    """
    return partial[0, 0], partial[-1, 0]


def partials_stretch(partials: List[np.ndarray], factor: float, inplace=False
                     ) -> List[np.ndarray]:
    """
    Stretch the partials in time by a given constant factor

    Args:
        partials: a list of partials
        factor: float. a factor to multiply all times by
        inplace: modify partials in place

    Returns:
        the stretched partials
    """
    if inplace:
        for p in partials:
            p[:, 0] *= factor
        return partials
    else:
        out = []
        for p in partials:
            p = p.copy()
            p[:, 0] *= factor
            out.append(p)
        return out


def i2r(interval: float) -> float:
    """
    Interval to ratio
    """
    return 2**(interval/12.)


def partials_transpose(partials: List[np.ndarray], interval: float, inplace=False
                       ) -> List[np.ndarray]:
    """
    Transpose the partials by a given interval
    """
    factor = i2r(interval)
    if inplace:
        for p in partials:
            p[:, 1] *= factor
        return partials
    else:
        out = []
        for p in partials:
            p = p.copy()
            p[:, 1] *= interval
            out.append(p)
        return out


def partials_timerange(partials: List[np.ndarray]) -> Tuple[float, float]:
    """
    Return the timerange of the partials: (begin, end)
    """
    t0 = partials[0][0, 0]
    t1 = max(p[-1, 0] for p in partials)
    return t0, t1


def partials_between(partials: List[np.ndarray], t0=0., t1=0.) -> List[np.ndarray]:
    """
    Return the partials present between t0 and t1

    Args:
        partials: a list of partials
        t0: start time in secs
        t1: end time in secs

    Returns:
        the partials within the time range (t0, t1)
    """
    if t1 == 0:
        t1 = partials_timerange(partials)[-1]
    out = []
    for p in partials:
        pt0, pt1 = partial_timerange(p)
        if pt1 > t0 and pt0 < t1:
            out.append(p)
        elif pt0 > t1:
            break
    return out


def _f2m(freq, A4=442):
    if freq < 9:
        return 0
    return 12.0*math.log(freq/A4, 2)+69.0


def _amp2db(amp):
    return math.log10(amp)*20


_enharmonics = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', 'C'
]
_notes3 = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C'
]


def _m2n(midinote: float) -> str:
    i = int(midinote)
    micro = midinote-i
    octave = int(midinote/12.0)-1
    ps = int(midinote%12)
    cents = int(micro*100+0.5)
    if cents == 0:
        return str(octave)+_notes3[ps]
    elif cents == 50:
        if ps in (1, 3, 6, 8, 10):
            return str(octave)+_notes3[ps+1]+'-'
        return str(octave)+_notes3[ps]+'+'
    elif cents > 50:
        cents = 100-cents
        ps += 1
        if ps > 11:
            octave += 1
        if cents > 9:
            return "%d%s-%d"%(octave, _enharmonics[ps], cents)
        else:
            return "%d%s-0%d"%(octave, _enharmonics[ps], cents)
    else:
        if cents > 9:
            return "%d%s+%d"%(octave, _notes3[ps], cents)
        else:
            return "%d%s+0%d"%(octave, _notes3[ps], cents)


def partials_at(partials: List[np.ndarray], t: float, maxcount=0, mindb=-120,
                minfreq=10, maxfreq=22000):
    """
    Return the breakpoints at time t which satisfy the given conditions

    Args:
        partials: the partials analyzed
        t: the time in seconds
        maxcount: the max. partials to detect, ordered by amplitude (0=all)
        mindb: the min. amplitude a partial has to have at `t` in order to be counted
        minfreq: only partials with a freq. higher than this
        maxfreq: only partials with a freq. lower than this

    Returns:
        the breakpoints at time t which satisfy the given conditions
    """
    EPS = 0.000000001
    present = partials_between(partials, t-EPS, t+EPS)
    allbps = [partial_at(partial, t) for partial in present]
    minamp = db2amp(mindb)
    bps = [
        bp for bp in allbps if minfreq<=bp[0] < maxfreq and bp[1] > minamp
    ]
    if maxcount == 0:
        return bps
    bps.sort(key=lambda bp:bp[1], reverse=True)
    return bps[:maxcount]


def breakpoints_extend(bps, dur):
    """
    Given a list of breakpoints, extend each to a partial with the
    given duration

    ### Example

    ```python

    samples, sr = sndreadmono("...")
    partials = analyze(samples, sr, resolution=50)
    breakpoints = partials_at(partials, 0.5, maxcount=4)
    print(breakpoints_to_chord(breakpoints))
    partials_render(breakpoints_extend(breakpoints, 4), outfile="chord.wav", open=True)
    
    ```
    
    Args:
        bps: a list of breakpoints, as returned by `partials_at`
        dur: the duration of the resulting partial

    """
    partials = []
    for bp in bps:
        partial = np.zeros(shape=(2, 5), dtype=float)
        partial[0, 1:] = bp
        partial[1, 0] = dur
        partial[1, 1:] = bp
        partials.append(partial)
    return partials


def breakpoints_to_chord(bps, A4=442) -> Tuple[str, float, float]:
    """
    Convert breakpoints (as returned by partials_at) to a list of
    (notename, freq, amplitude_db)
    """
    out = []
    for bp in bps:
        freq = bp[0]
        amp = bp[1]
        notename = _m2n(_f2m(freq, A4=A4))
        db = _amp2db(amp)
        out.append((notename, freq, db))
    if out:
        out.sort()
    return out


def partials_render(partials: List[np.ndarray], outfile: str, sr=44100,
                    fadetime=-1., start=-1., end=-1., encoding: str = None
                    ) -> None:
    """
    Render partials as a soundfile

    Args:
        partials: the partials to render
        outfile: the outfile to write to. If not given, a temporary file is used
        sr: samplerate to render with
        fadetime: fade partials in/out when they don't end in a 0-amp bp
        start: start time of render (default: start time of spectrum)
        end: end time to render (default: end time of spectrum)
        encoding: if given, the encoding to use

    Returns:
        the path to the oufile written
    """
    samples = _core.synthesize(partials,
                               samplerate=sr,
                               fadetime=fadetime,
                               start=start,
                               end=end)
    sndwrite(samples, sr=sr, path=outfile, encoding=encoding)


def chord_to_partials(chord: List[Tuple[float, float]], dur: float, fade=0.1,
                      startmargin=0., endmargin=0.
                      ) -> List[np.ndarray]:
    """
    Generate partials from the given chord

    Args:
        chord: a list of (freq, amp) tuples
        dur: the duration of the partials
        fade: the fade time
        startmargin: ??
        endmargin ??
    """
    partials = []
    start = max(startmargin, 0.001)
    for row in chord:
        freq, ampnow = row
        assert isinstance(freq, (int, float))
        assert isinstance(ampnow, (int, float)) and ampnow>=0
        mtx = [[0, freq, 0, 0, 0],
               [start, freq, 0, 0, 0],
               [start+fade, freq, ampnow, 0, 0],
               [start+dur-fade*2, freq, ampnow, 0, 0],
               [start+dur, freq, 0, 0, 0]]
        if endmargin > 0:
            mtx.append([start+dur+endmargin, freq, 0, 0, 0])

        partial = np.array(mtx, dtype=float)
        partials.append(partial)
    return partials


def _get_frame_times(partials: List[np.ndarray]) -> np.ndarray:
    allbps = []
    for i, partial in enumerate(partials):
        partialidx = np.ones(shape=(len(partial),), dtype=float)*i
        bps = np.column_stack((partial[:,0], partialidx))
        allbps.append(bps)
    bparray = np.row_stack(allbps)
    bparray = bparray[bparray[:, 0].argsort()]
    seen = set()
    frametimes = [bparray[0, 0]]
    for i in range(len(bparray)):
        row = bparray[i]
        idx = int(row[1])
        if idx not in seen:
            seen.add(idx)
        else:
            frametimes.append(row[0])
            seen.clear()
            seen.add(idx)
    return np.array(frametimes, dtype=float)


def _write_sdif_1trc(partials: List[np.ndarray], outfile: str, 
                     labels:U[List[int], np.ndarray]=None, fadetime=0.
                     ) -> None:
    if labels:
        logger.warn("labels are not supported (at the moment) when writing to 1TRC sdif")
    import pysdif
    sdif = pysdif.SdifFile(outfile, "w")
    sdif.add_NVT({'creator': 'pysdif3'})
    #sdif.add_matrix_type("1TRC", "Index, Frequency, Amplitude, Phase")
    #sdif.add_frame_type("1TRC", ["1TRC SinusoidalTracks"])
    
    frametimes = _get_frame_times(partials)
    partials = [partial_sample_at(p, frametimes) for p in partials]

    allbps = []
    for i, partial in enumerate(partials):
        partialidx = np.ones(shape=(len(partial),), dtype=float)*i
        bps = np.column_stack((partial, partialidx))
        allbps.append(bps)
    bparray = np.row_stack(allbps)
    bparray = bparray[bparray[:, 0].argsort()]
    seen = set()
    startidx = 0
    for i in range(len(bparray)):
        row = bparray[i]
        #       t f a p b i
        # 1trc: i f a p 
        idx = int(row[5])
        if idx not in seen:
            seen.add(idx)
        else:
            data = bparray[startidx:i]
            t0 = data[0, 0]
            frame = data[:, (5, 1, 2, 3)]
            if not frame.flags.c_contiguous:
                frame = np.ascontiguousarray(frame)
            sdif.new_frame_one_matrix("1TRC", t0, "1TRC", frame)
            startidx = i
            seen.clear()
            seen.add(idx)


def partial_fade(partial: np.ndarray, fadein=0., fadeout: float=0.
                 ) -> np.ndarray:
    """
    Apply a fadein / fadeout to this partial so that the first and last
    breakpoints have an amplitude = 0

    This is only applied if the partial starts or ends in non-zero amplitude

    Args:
        partial: the partial to fade
        fadein: the fadein time. If 0 and the first breakpoint has a non-zero
            amplitude, zero the first amplitude in the partial
        fadeout: the fadeout time. If 0 and the last breakpoint has a non-zero
            aplitude, zero the last amplitude in the partial.

    Returns:
        the faded partial
    """
    if fadein == 0 and fadeout == 0:
        # in place
        partial[0, 0] = 0
        partial[-1, 0] = 0
        return partial
    partial2 = np.zeros((len(partial+2, 5)))
    partial2[1:-1] = partial
    t0 = max(0, partial[0, 0] - fadein)
    partial2[0] = partial[0]
    partial2[0, 0] = t0
    partial2[0, 2] = 0
    partial2[-1] = partial[-1]
    t1 = partial[-1, 0] + fadeout
    partial2[-1, 0] = t1
    partial2[-1, 2] = 0
    return partial


def _write_sdif_rbep(partials: List[np.ndarray], outfile: str, 
                     labels:U[List[int], np.ndarray]=None
                     ) -> None:
    """
    Args:
        partials: the partials to write
        outfile: the path of the sdif file to generate
        labels: if given, a list of integers with the same size as the partials, 
            one label per partial
    """
    import pysdif
    sdif = pysdif.SdifFile(outfile, "w")
    sdif.add_NVT({'creator': 'pysdif3'})
    sdif.add_matrix_type("RBEP",
                         "Index, Frequency, Amplitude, Phase, Bandwidth, Offset")
    if labels:
        sdif.add_matrix_type("RBEL", "Index, Label")

    sdif.add_frame_type("RBEP", ["RBEP ReassignedBandEnhancedPartials"])
    if labels:
        sdif.add_frame_type("RBEL", ["RBEL PartialLabels"])
        if isinstance(labels, list):
            assert len(labels) == len(partials)
            labelframe = np.asarray(labels, dtype=float)
        elif isinstance(labels, np.ndarray):
            assert len(labels.shape) == 1 and labels.shape[0] == len(partials)
            labelframe = labels
        else:
            raise TypeError(f"Expected a list of ints or a numpy array, got {type(labels)}")
        sdif.new_frame_one_matrix("RBEL", 0, "RBEL", labelframe)

    allbps = []
    for i, partial in enumerate(partials):
        partialidx = np.ones(shape=(len(partial),), dtype=float)*i
        bps = np.column_stack((partial, partialidx))
        allbps.append(bps)
    bparray = np.row_stack(allbps)
    bparray = bparray[bparray[:, 0].argsort()]
    seen = set()
    startidx = 0
    for i in range(len(bparray)):
        # print(i, len(bparray))
        row = bparray[i]
        #       t f a p b i
        # rbep: i f a p b offset
        idx = int(row[5])
        if idx not in seen:
            seen.add(idx)
        else:
            data = bparray[startidx:i]
            times = data[:, 0]
            t0 = times[0]            
            offsets = times - t0
            rbepframe = data.copy()
            rbepframe[:,0] = data[:,5]
            rbepframe[:,5] = offsets
            # rbepframe = np.column_stack((data[:, (5, 1, 2, 3, 4)], offsets))
            if not rbepframe.flags.c_contiguous:
                rbepframe = np.ascontiguousarray(rbepframe)
            sdif.new_frame_one_matrix("RBEP", t0, "RBEP", rbepframe)
            startidx = i
            seen.clear()
            seen.add(idx)


def write_sdif(partials: List[np.ndarray], outfile: str, labels=None, fmt="RBEP", fadetime=0.) -> None:
    """
    Write a list of partials as SDIF.  
    
    !!! note

        The 1TRC format forces resampling, since all breakpoints within a 
        1TRC frame need to share the same timestamp. In the RBEP format
        a breakpoint has a time offset to the frame time stamp
    
    Args:
        partials: a seq. of 2D arrays with columns [time freq amp phase bw]
        outfile: the path of the sdif file
        labels: a seq. of integer labels, or None to skip saving labels
        fmt: one of "RBEP" / "1TRC"
       
    """
    if fmt == "RBEP":
        _write_sdif_rbep(partials, outfile, labels=labels)
    elif fmt == "1TRC":
        _write_sdif_1trc(partials, outfile, labels=labels)
        # _core._write_sdif(partials, outfile, labels=labels, rbep=rbep, fadetime=fadetime)
    else:
        raise ValueError("Formats supported: RBEP, 1TRC")