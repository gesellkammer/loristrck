# loristrck.util


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



----------

## concat


Concatenate multiple Partials to produce a new one.


```python

def concat(partials: list[np.ndarray], fade: float = 0.005, 
           edgefade: float = 0.0) -> np.ndarray

```


Assumes that the partials are non-overlapping and sorted

!!! note

    partials need to be non-simultaneous and sorted



**Args**

* **partials** (`List[np.ndarray]`): a seq. of partials (each partial is a
    2D-array)
* **fade** (`float`): fadetime to apply at the end/beginning of each
    concatenated partial (default: 0.005)
* **edgefade** (`float`): a fade to apply at the beginning of the first and at
    the end of the last partial (default: 0.0)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) a numpy array representing the concatenation of the given partials

----------

## partial\_at


Evaluates partial `p` at time `t`


```python

def partial_at(p: np.ndarray, t: float, extend: bool = False) -> Opt[np.ndarray]

```



**Args**

* **p** (`np.ndarray`): the partial, a 2D numpy array
* **t** (`float`): the time to evaluate the partial at
* **extend** (`bool`): should the partial be extended to -inf, +inf? If True,
    querying a partial         outside its boundaries will result in the values
    at the boundaries.         Otherwise, None is returned (default: False)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Opt[np.ndarray]`) with columns (time, freq, amp, bw). Returns None if the array is not defined at the given time

----------

## partial\_crop


Crop partial at times t0, t1


```python

def partial_crop(p: np.ndarray, t0: float, t1: float) -> np.ndarray

```


!!! note

    * Returns p if p is included in the interval t0-t1
    * Returns None if partial is not defined between t0-t1
    * Otherwise crops the partial at t0 and t1, places a breakpoint
      at that time with the interpolated value



**Args**

* **p** (`np.ndarray`): the partial
* **t0** (`float`): the start time
* **t1** (`float`): the end time

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) if the partial is not defined within the given time constraints)

----------

## partials\_sample


Samples the partials between times `t0` and `t1` with a sampling period `dt`


```python

def partials_sample(partials: list[np.ndarray], dt: float = 0.002, 
                    t0: float = -1, t1: float = -1, maxactive: int = 0, 
                    interleave: bool = True) -> Any

```


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



**Args**

* **partials** (`List[np.ndarray]`): a list of 2D-arrays, each representing a
    partial
* **dt** (`float`): sampling period (default: 0.002)
* **t0** (`float`): start time, or None to use the start time of the spectrum
    (default: -1)
* **t1** (`float`): end time, or None to use the end time of the spectrum
    (default: -1)
* **maxactive** (`int`): limit the number of active partials to this number. If
    the         number of active streams (partials with non-zero amplitude) is
    higher than `maxactive`, the softest partials will be zeroed.         During
    resynthesis, zeroed partials are skipped.         This strategy is followed
    to allow to pack all partials at the cost         of having a great amount
    of streams, and limit the streams (for         better performance) at the
    synthesis stage. (default: 0)
* **interleave** (`bool`): if True, all columns of each partial are interleaved
    (see below) (default: True)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;if interleave is True, returns a big matrix where all partials are interleaved and present at all times. Otherwise returns three arrays, (freqs, amps, bws) where freqs represents the frequencies of all partials, etc. See below

----------

## meanamp


Returns the mean amplitude of a partial


```python

def meanamp(partial: np.ndarray) -> float

```



**Args**

* **partial** (`np.ndarray`): a numpy 2D-array representing a Partial

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the average amplitude

----------

## meanfreq


Returns the mean frequency of a partial, optionally


```python

def meanfreq(partial: np.ndarray, weighted: bool = False) -> float

```


weighting this mean by the amplitude of each breakpoint



**Args**

* **partial** (`np.ndarray`):
* **weighted** (`bool`):  (default: False)

----------

## partial\_energy


Integrate the partial amplitude over time. Serves as measurement


```python

def partial_energy(partial: np.ndarray) -> float

```


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



**Args**

* **partial** (`np.ndarray`):

----------

## select


Selects a seq. of partials matching the given conditions


```python

def select(partials: list[np.ndarray], mindur: float = 0.0, minamp: int = -120, 
           maxfreq: int = 24000, minfreq: int = 0, minbps: int = 1, 
           t0: float = 0.0, t1: float = 0.0
           ) -> tuple[list[np.ndarray], list[np.ndarray]]

```


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



**Args**

* **partials** (`List[np.ndarray]`): a list of numpy 2D arrays, each array
    representing a partial
* **mindur** (`float`): min. duration (in seconds) (default: 0.0)
* **minamp** (`int`): min. amplitude (in dB) (default: -120)
* **maxfreq** (`int`): max. frequency (default: 24000)
* **minfreq** (`int`): min. frequency (default: 0)
* **minbps** (`int`): min. breakpoints (default: 1)
* **t0** (`float`): only partials defined after t0 (default: 0.0)
* **t1** (`float`): only partials defined before t1 (default: 0.0)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Tuple[List[np.ndarray], List[np.ndarray]]`) (selected partials, discarded partials)

----------

## filter


Similar to select, but returns a generator yielding only selected partials


```python

def filter(partials: list[np.ndarray], mindur: float = 0.0, mindb: int = -120, 
           maxfreq: int = 2400, minfreq: int = 0, minbps: int = 1, 
           t0: float = 0.0, t1: float = 0.0) -> None

```



**Args**

* **partials** (`List[np.ndarray]`):
* **mindur** (`float`):  (default: 0.0)
* **mindb** (`int`):  (default: -120)
* **maxfreq** (`int`):  (default: 2400)
* **minfreq** (`int`):  (default: 0)
* **minbps** (`int`):  (default: 1)
* **t0** (`float`):  (default: 0.0)
* **t1** (`float`):  (default: 0.0)

----------

## sndread


Read a sound file.


```python

def sndread(path: str, contiguous: bool = True) -> tuple[np.ndarray, int]

```



**Args**

* **path** (`str`): The path to the soundfile
* **contiguous** (`bool`): If True, it is ensured that the returned array
    is contiguous. This should be set to True if the samples are to be
    passed to `analyze`, which expects a contiguous array (default: True)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Tuple[np.ndarray, int]`) a tuple (samples:np.ndarray, sr:int)

----------

## sndreadmono


Read a sound file as mono.


```python

def sndreadmono(path: str, chan: int = 0, contiguous: bool = True
                ) -> tuple[np.ndarray, int]

```


If the soundfile is multichannel, the indicated channel `chan` is returned.



**Args**

* **path** (`str`): The path to the soundfile
* **chan** (`int`): The channel to return if the file is multichannel (default:
    0)
* **contiguous** (`bool`): If True, it is ensured that the returned array
    is contiguous. This should be set to True if the samples are to be
    passed to `analyze`, which expects a contiguous array (default: True)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Tuple[np.ndarray, int]`) a tuple (samples:np.ndarray, sr:int)

----------

## sndwrite


Write the samples to a soundfile


```python

def sndwrite(samples: np.ndarray, sr: int, path: str, encoding: str = None
             ) -> None

```



**Args**

* **samples** (`np.ndarray`): the samples to write
* **sr** (`int`): samplerate
* **path** (`str`): the outfile to write the samples to (the extension will
    determine the format)
* **encoding** (`str`): the encoding of the samples. If None, a default is used,
    according to         the extension of the outfile given. Otherwise, a string
    'floatXX' or 'pcmXX'         is expected, where XX represent the bits per
    sample (15, 24, 32, 64 for pcm,         32 or 64 for float). Not all
    encodings are supported by all formats. (default: None)

----------

## plot\_partials


Plot the partials using matplotlib


```python

def plot_partials(partials: list[np.ndarray], downsample: int = 1, 
                  cmap: str = inferno, exp: float = 1.0, linewidth: int = 1, 
                  ax=None, avg: bool = True) -> Any

```



**Args**

* **partials** (`List[np.ndarray]`): a list of numpy arrays, each representing a
    partial
* **downsample** (`int`): If > 1, only one every `downsample` breakpoints will
    be taken         into account. (default: 1)
* **cmap** (`str`): a string defining the colormap used         (see
    <https://matplotlib.org/users/colormaps.html>) (default: inferno)
* **exp** (`float`): an exponential to apply to the amplitudes before plotting
    (default: 1.0)
* **linewidth** (`int`): the line width of the plot (default: 1)
* **ax**: A matplotlib axes. If one is passed, plotting will be done to this
    axes. Otherwise a new axes is created (default: None)
* **avg** (`bool`): if True, the colour of a segment depends on the average
    between the         amplitude at the start breakpoint and the end breakpoint
    of the segment         Otherwise only the amplitude of the start breakpoint
    is used (default: True)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;a matplotlib axes

----------

## kaiser\_length


Returns the length in samples of a Kaiser window from the desired main lobe width.


```python

def kaiser_length(width: float, sr: int, atten: int) -> int

```


!!! note

    computeLength

    Compute the length (in samples) of the Kaiser window from the desired
    (approximate) main lobe width and the control parameter. Of course, since
    the window must be an integer number of samples in length, your actual
    lobal mileage may vary. This equation appears in Kaiser and Schafer 1980
    (on the use of the I0 window class for spectral analysis) as Equation 9.
    The main width of the main lobe must be normalized by the sample rate,
    that is, it is a fraction of the sample rate.



**Args**

* **width** (`float`): the width of the main lobe in Hz
* **sr** (`int`): the sample rate, in samples / sec
* **atten** (`int`): the attenuation in possitive dB

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`int`) the length of the window, in samples

----------

## partials\_stretch


Stretch the partials in time by a given constant factor


```python

def partials_stretch(partials: list[np.ndarray], factor: float, 
                     inplace: bool = False) -> list[np.ndarray]

```



**Args**

* **partials** (`List[np.ndarray]`): a list of partials
* **factor** (`float`): float. a factor to multiply all times by
* **inplace** (`bool`): modify partials in place (default: False)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`List[np.ndarray]`) the stretched partials

----------

## partials\_transpose


Transpose the partials by a given interval


```python

def partials_transpose(partials: list[np.ndarray], interval: float, 
                       inplace: bool = False) -> list[np.ndarray]

```



**Args**

* **partials** (`List[np.ndarray]`):
* **interval** (`float`):
* **inplace** (`bool`):  (default: False)

----------

## partials\_between


Return the partials present between t0 and t1


```python

def partials_between(partials: list[np.ndarray], t0: float = 0.0, 
                     t1: float = 0.0) -> list[np.ndarray]

```



**Args**

* **partials** (`List[np.ndarray]`): a list of partials
* **t0** (`float`): start time in secs (default: 0.0)
* **t1** (`float`): end time in secs (default: 0.0)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`List[np.ndarray]`) the partials within the time range (t0, t1)

----------

## partials\_at


Return the breakpoints at time t which satisfy the given conditions


```python

def partials_at(partials: list[np.ndarray], t: float, maxcount: int = 0, 
                mindb: int = -120, minfreq: int = 10, maxfreq: int = 22000
                ) -> Any

```



**Args**

* **partials** (`List[np.ndarray]`): the partials analyzed
* **t** (`float`): the time in seconds
* **maxcount** (`int`): the max. partials to detect, ordered by amplitude
    (0=all) (default: 0)
* **mindb** (`int`): the min. amplitude a partial has to have at `t` in order to
    be counted (default: -120)
* **minfreq** (`int`): only partials with a freq. higher than this (default: 10)
* **maxfreq** (`int`): only partials with a freq. lower than this (default:
    22000)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;the breakpoints at time t which satisfy the given conditions

----------

## partials\_render


Render partials as a soundfile


```python

def partials_render(partials: list[np.ndarray], outfile: str, sr: int = 44100, 
                    fadetime: float = -1.0, start: float = -1.0, 
                    end: float = -1.0, encoding: str = None) -> None

```



**Args**

* **partials** (`List[np.ndarray]`): the partials to render
* **outfile** (`str`): the outfile to write to. If not given, a temporary file
    is used
* **sr** (`int`): samplerate to render with (default: 44100)
* **fadetime** (`float`): fade partials in/out when they don't end in a 0-amp bp
    (default: -1.0)
* **start** (`float`): start time of render (default: start time of spectrum)
    (default: -1.0)
* **end** (`float`): end time to render (default: end time of spectrum)
    (default: -1.0)
* **encoding** (`str`): if given, the encoding to use (default: None)

----------

## estimate\_sampling\_interval


Estimate a sampling interval (dt) for this spectrum


```python

def estimate_sampling_interval(partials: list[np.ndarray], maxpartials: int = 0, 
                               percentile: int = 25, ksmps: int = 64, 
                               sr: int = 44100) -> float

```


The usage is to find a sampling interval which neither oversamples
nor undersamples the partials for a synthesis strategy based on blocks of
computation (like in csound, supercollider, etc, where each ugen is given
a buffer of samples to fill instead of working sample by sample)



**Args**

* **partials** (`List[np.ndarray]`): a list of partials
* **maxpartials** (`int`): if given, only consider this number of partials to
    calculate dt (default: 0)
* **percentile** (`int`): ??? (default: 25)
* **ksmps** (`int`): samples per cycle used when rendering. This is used in the
    estimation         to prevent oversampling (default: 64)
* **sr** (`int`): the sample rate used for playback, used together with ksmps to
    estimate         a useful sampling interval (default: 44100)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the most appropriate sampling interval for the data and the playback conditions

----------

## pack


Pack non-simultenous partials into longer partials with silences in between.


```python

def pack(partials: list[np.ndarray], maxtracks: int = 0, gap: float = 0.01, 
         fade: float = -1.0, acceptabledist: float = 0.1, minbps: int = 2
         ) -> tuple[list[np.ndarray], list[np.ndarray]]

```


These packed partials can be used as tracks for resynthesis, minimizing the need
of oscillators.

!!! note

    Amplitude is always faded out between partials

**See also**: [partials_save_matrix](util.md#partials_save_matrix)



**Args**

* **partials** (`List[np.ndarray]`): a list of arrays, where each array
    represents a partial,         as returned by analyze
* **maxtracks** (`int`): if > 0, sets the maximum number of tracks. Partials not
    fitting in will be discarded. Consider living this at 0, to allow
    for unlimited tracks, and limit the amount of active streams later
    on (default: 0)
* **gap** (`float`): minimum gap between partials in a track. Should be longer
    than         2 times the sampling interval, if the packed partials are later
    going to be resampled. (default: 0.01)
* **fade** (`float`): apply a fade to the partials before joining them.
    If not given, a default value is calculated (default: -1.0)
* **acceptabledist** (`float`): instead of searching for the best possible fit,
    pack         two partials together if they are near enough (default: 0.1)
* **minbps** (`int`): the min. number of breakpoints for a partial to the
    packed. Partials         with less that this number of breakpoints are
    filtered out (default: 2)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Tuple[List[np.ndarray], List[np.ndarray]]`) a tuple (tracks, unpacked partials)

----------

## partials\_save\_matrix


Packs short partials into longer partials and saves the result as a matrix


```python

def partials_save_matrix(partials: list[np.ndarray], outfile: str, 
                         dt: float = None, gapfactor: float = 3.0, 
                         maxtracks: int = 0, maxactive: int = 0
                         ) -> tuple[list[np.ndarray], np.ndarray]

```


### Example

```python

import loristrck as lt
partials, labels = lt.read_sdif(sdiffile)
selected, rest = lt.util.select(partials, minbps=2, mindur=0.005, minamp=-80)
lt.util.partials_save_matrix(selected, 0.002, "packed.mtx")

```



**Args**

* **partials** (`List[np.ndarray]`): a list of numpy 2D-arrays, each
    representing a partial
* **outfile** (`str`): path to save the sampled partials. Supported formats:
    `.mtx`, `.npy`         (See matrix_save for more information)
* **dt** (`float`): sampling period to sample the packed partials. If not given,
    it will be estimated with sensible defaults. To have more control
    over this stage, you can call estimate_sampling_interval yourself.
    At the cost of oversampling, a good value can be ksmps/sr, which results
    in 64/44100 = 0.0014 secs for typical values (default: None)
* **gapfactor** (`float`): partials are packed with a gap = dt * gapfactor.
    It should be at least 2. A gap is a minimal amount of silence
    between the partials to allow for a fade out and fade in (default: 3.0)
* **maxtracks** (`int`): Partials are packed in tracks and represented as a 2D
    matrix where         each track is a row. If filesize and save/load time are
    a concern,         a max. value for the amount of tracks can be given here,
    with the         consequence that partials might be left out if there are no
    available         tracks to pack them into. See also `maxactive` (default:
    0)
* **maxactive** (`int`): Partials are packed in simultaneous tracks, which
    correspond to         an oscillator bank for resynthesis. If maxactive is
    given,         a max. of `maxactive` is allowed, and the softer partials are
    zeroed to signal that they can be skipped during resynthesis. (default: 0)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`Tuple[List[np.ndarray], np.ndarray]`) a tuple (packed spectrum, matrix)