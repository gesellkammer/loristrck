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



---------


| Class  | Description  |
| :----  | :----------- |
| `PartialIndex` | Create an index to accelerate finding partials |

| Function  | Description  |
| :-------  | :----------- |
| `breakpoints_extend` | Given a list of breakpoints, extend each to form a partial of the given dur |
| `breakpoints_to_chord` | Convert breakpoints to a list of (notename, freq, amplitude_db |
| `chord_to_partials` | Generate partials from the given chord |
| `concat` | Concatenate multiple Partials to produce a new one. |
| `db2amp` | Convert amplitude in dB to linear amplitude |
| `db2ampnp` | Convert amplitude in dB to linear amplitude for a numpy array |
| `estimate_sampling_interval` | Estimate a sampling interval (dt) for this spectrum |
| `filter` | Similar to select, but returns a generator yielding only selected partials |
| `i2r` | Interval to ratio |
| `kaiser_length` | Returns the length in samples of a Kaiser window from the desired main lobe width. |
| `loudest` | Get the loudest N partials. |
| `matrix_save` | Save the raw data mtx. |
| `meanamp` | Returns the mean amplitude of a partial |
| `meanfreq` | Returns the mean frequency of a partial |
| `pack` | Pack non-simultenous partials into longer partials with silences in between. |
| `partial_at` | Evaluates partial `p` at time `t` |
| `partial_crop` | Crop partial at times t0, t1 |
| `partial_energy` | Integrate the partial amplitude over time. |
| `partial_fade` | Apply a fadein / fadeout to this partial so that the first and last |
| `partial_sample_at` | Sample a partial `p` at given times |
| `partial_sample_regularly` | Sample a partial `p` at regular time intervals |
| `partial_timerange` | Return begin and endtime of partial |
| `partials_at` | Sample the partials which satisfy the given conditions at time t |
| `partials_between` | Return the partials present between t0 and t1 |
| `partials_render` | Render partials as a soundfile |
| `partials_sample` | Samples the partials between times `t0` and `t1` with sampling period `dt` |
| `partials_save_matrix` | Packs short partials into longer partials and saves the result as a matrix |
| `partials_stretch` | Stretch the partials in time by a given constant factor |
| `partials_timerange` | Return the timerange of the partials: (begin, end) |
| `partials_transpose` | Transpose the partials by a given interval |
| `plot_partials` | Plot the partials using matplotlib |
| `select` | Selects a seq. of partials matching the given conditions |
| `sndread` | Read a sound file. |
| `sndreadmono` | Read a sound file as mono. |
| `sndwrite` | Write the samples to a soundfile |
| `wavwrite` | Write samples to a wav-file (see also sndwrite) as float32 or float64 |
| `write_sdif` | Write a list of partials as SDIF. |



---------


## PartialIndex
### 


```python

def () -> None

```


Create an index to accelerate finding partials


After creating the PartialIndex, each call to `partialindex.partials_between`
should be faster than simply calling `partials_index` since the unoptimized
function needs to always start a linear search from the beginning of the
partials list.

!!! note

    The index is only valid as long as the original partial list is not
    modified


---------


**Summary**



| Method  | Description  |
| :------ | :----------- |
| [__init__](#__init__) | - |
| [partials_between](#partials_between) | Returns the partials which are defined within the given time range |


---------


---------


**Methods**

### \_\_init\_\_


```python

def __init__(self, partials: list[np.ndarray], dt: float = 1.0) -> None

```



**Args**

* **partials** (`list[np.ndarray]`): the partials to index
* **dt** (`float`): the time resolution of the index. The lower this value the
    faster         each query will be but the slower the creation of the index
    itself (*default*: `1.0`)

----------

### partials\_between


```python

def partials_between(self, t0: float, t1: float) -> list[np.ndarray]

```


Returns the partials which are defined within the given time range



**Args**

* **t0** (`float`): the start of the time interval
* **t1** (`float`): the end of the time interval

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) a list of partials present during the given time range



---------


## breakpoints\_extend


```python

def breakpoints_extend(bps, dur: float) -> list[np.ndarray]

```


Given a list of breakpoints, extend each to form a partial of the given dur


### Example

```python

samples, sr = sndreadmono("...")
partials = analyze(samples, sr, resolution=50)
selected = partials_between(partials, 0.5, 0.5)
breakpoints = partials_at(selected, 0.5, maxcount=4)
print(breakpoints_to_chord(breakpoints))
partials_render(breakpoints_extend(breakpoints, 4), outfile="chord.wav", open=True)

```



**Args**

* **bps**: a list of breakpoints, as returned by `partials_at`
* **dur** (`float`): the duration of the resulting partial


---------


## breakpoints\_to\_chord


```python

def breakpoints_to_chord(bps, A4: int = 442) -> tuple[str, float, float]

```


Convert breakpoints to a list of (notename, freq, amplitude_db



**Args**

* **bps**: the breakpoints, as returned, for example, by partials_at
* **A4** (`int`):  (*default*: `442`)


---------


## chord\_to\_partials


```python

def chord_to_partials(chord: list[tuple[float, float]], dur: float, 
                      fade: float = 0.1, startmargin: float = 0.0, 
                      endmargin: float = 0.0) -> list[np.ndarray]

```


Generate partials from the given chord



**Args**

* **chord** (`list[tuple[float, float]]`): a list of (freq, amp) tuples
* **dur** (`float`): the duration of the partials
* **fade** (`float`): the fade time (*default*: `0.1`)
* **startmargin** (`float`): ??     endmargin ?? (*default*: `0.0`)
* **endmargin** (`float`):  (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) a list of partials


---------


## concat


```python

def concat(partials: list[np.ndarray], fade: float = 0.005, 
           edgefade: float = 0.0) -> np.ndarray

```


Concatenate multiple Partials to produce a new one.


Assumes that the partials are non-overlapping and sorted

!!! note

    partials need to be non-simultaneous and sorted



**Args**

* **partials** (`list[np.ndarray]`): a seq. of partials (each partial is a
    2D-array)
* **fade** (`float`): fadetime to apply at the end/beginning of each
    concatenated partial (*default*: `0.005`)
* **edgefade** (`float`): a fade to apply at the beginning of the first and at
    the end of the last partial (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) a numpy array representing the concatenation of the given partials


---------


## db2amp


```python

def db2amp(x: float) -> float

```


Convert amplitude in dB to linear amplitude



**Args**

* **x** (`float`): the value in dB to convert to amplitude

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the amplitude of x as linear amplitude


---------


## db2ampnp


```python

def db2ampnp(x: np.ndarray) -> np.ndarray

```


Convert amplitude in dB to linear amplitude for a numpy array



**Args**

* **x** (`np.ndarray`): the dB values to convert

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) the corresponding linear amplitudes


---------


## estimate\_sampling\_interval


```python

def estimate_sampling_interval(partials: list[np.ndarray], maxpartials: int = 0, 
                               percentile: int = 25, ksmps: int = 64, 
                               sr: int = 44100) -> float

```


Estimate a sampling interval (dt) for this spectrum


The usage is to find a sampling interval which neither oversamples
nor undersamples the partials for a synthesis strategy based on blocks of
computation (like in csound, supercollider, etc, where each ugen is given
a buffer of samples to fill instead of working sample by sample)



**Args**

* **partials** (`list[np.ndarray]`): a list of partials
* **maxpartials** (`int`): if given, only consider this number of partials to
    calculate dt (*default*: `0`)
* **percentile** (`int`): ??? (*default*: `25`)
* **ksmps** (`int`): samples per cycle used when rendering. This is used in the
    estimation         to prevent oversampling (*default*: `64`)
* **sr** (`int`): the sample rate used for playback, used together with ksmps to
    estimate         a useful sampling interval (*default*: `44100`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the most appropriate sampling interval for the data and the playback conditions


---------


## filter


```python

def filter(partials: list[np.ndarray], mindur: float = 0.0, mindb: int = -120, 
           maxfreq: int = 20000, minfreq: int = 0, minbps: int = 1, 
           t0: float = 0.0, t1: float = 0.0) -> Any

```


Similar to select, but returns a generator yielding only selected partials



**Args**

* **partials** (`list[np.ndarray]`): the partials to filter
* **mindur** (`float`): the min. duration of a partial (*default*: `0.0`)
* **mindb** (`int`): the min. amplitude, in dB (*default*: `-120`)
* **maxfreq** (`int`): the max. frequency (*default*: `20000`)
* **minfreq** (`int`): the min. frequency (*default*: `0`)
* **minbps** (`int`): the min. number of breakpoints (*default*: `1`)
* **t0** (`float`): the start time (*default*: `0.0`)
* **t1** (`float`): the end time (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;an iterator over the partials which fulfill these conditions


---------


## i2r


```python

def i2r(interval: float) -> float

```


Interval to ratio



**Args**

* **interval** (`float`): the interval to convert to a ratio

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the ratio corresponding to the given interval (2 corresponds to an interval of an octave, 12)


---------


## kaiser\_length


```python

def kaiser_length(width: float, sr: int, atten: int) -> int

```


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



**Args**

* **width** (`float`): the width of the main lobe in Hz
* **sr** (`int`): the sample rate, in samples / sec
* **atten** (`int`): the attenuation in possitive dB

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`int`) the length of the window, in samples


---------


## loudest


```python

def loudest(partials: list[np.ndarray], N: int) -> list[np.ndarray]

```


Get the loudest N partials.


If N is not given, all partials are returned, sorted in declining energy

The returned partials will be sorted by declining energy
(integrated amplitude)



**Args**

* **partials** (`list[np.ndarray]`): the partials to select from
* **N** (`int`): the number of partials to select

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) the loudest N partials


---------


## matrix\_save


```python

def matrix_save(data: np.ndarray, outfile: str, bits: int = 32, 
                metadata: dict[str, Any] = None) -> None

```


Save the raw data mtx.


The data is saved either as a `.mtx` or as a `.npy` file.

### The mtx file format

The `mtx` is an ad-hoc format where a float-32 wav file is used to store binary
data. This .wav file is not a real soundfile, it is used as a binary storage
format. A header is always included, with the data `[headerSize, numRows, numColumns, ...]`
**headerSize** indicates the offset where the data starts. The data itself is saved flat,
starting at that offset. To reconstruct in python, do:

```python

import loristrck as lt
# discard sr, it has no meaning in this context
raw, _ = lt.sndread("mydata.mtx")
datastart = raw[0]
numrows = raw[1]
numcols = raw[2]
data = raw[datastart:]
data.shape = (numrows, numcols)
```

The `.npy` format is defined by numpy here:
<https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html#module-numpy
.lib.format>

The data `data` is a 1D or a 2D numpy array. 

#### Example

```python

import loristrck as lt
partials = lt.read_sdif(path_to_sdif)
tracks = lt.pack(partials)
dt = 64/44100
m = lt.partials_sample(tracks, dt)
matrix_save(m, "out.mtx")
```



**Args**

* **data** (`np.ndarray`): a 2D-matrix as returned by `partials_sample`
* **outfile** (`str`): the path to the resulting output file. The format should
    be         .mtx or .npy
* **bits** (`int`): 32 or 64. 32 bits should be enough (*default*: `32`)
* **metadata** (`dict[str, Any]`): if given, it is included in the wav metadata
    and all numeric         values are included in the data itself (*default*:
    `None`)


---------


## meanamp


```python

def meanamp(partial: np.ndarray) -> float

```


Returns the mean amplitude of a partial



**Args**

* **partial** (`np.ndarray`): a numpy 2D-array representing a Partial

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the average amplitude


---------


## meanfreq


```python

def meanfreq(partial: np.ndarray, weighted: bool = False) -> float

```


Returns the mean frequency of a partial


Optionally, frequencies can be weighted by the amplitude
of the breakpoint so that louder parts contribute more to the
average frequency as softer ones



**Args**

* **partial** (`np.ndarray`): the partial to evaluate
* **weighted** (`bool`): if True, weight the frequency by the amplitude
    (*default*: `False`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the average frequency


---------


## pack


```python

def pack(partials: list[np.ndarray], maxtracks: int = 0, gap: float = 0.01, 
         fade: float = -1.0, acceptabledist: float = 0.1, minbps: int = 2
         ) -> tuple[list[np.ndarray], list[np.ndarray]]

```


Pack non-simultenous partials into longer partials with silences in between.


These packed partials can be used as tracks for resynthesis, minimizing the need
of oscillators.

!!! note

    Amplitude is always faded out between partials

**See also**: [partials_save_matrix](util.md#partials_save_matrix)



**Args**

* **partials** (`list[np.ndarray]`): a list of arrays, where each array
    represents a partial,         as returned by analyze
* **maxtracks** (`int`): if > 0, sets the maximum number of tracks. Partials not
    fitting in will be discarded. Consider living this at 0, to allow
    for unlimited tracks, and limit the amount of active streams later
    on (*default*: `0`)
* **gap** (`float`): minimum gap between partials in a track. Should be longer
    than         2 times the sampling interval, if the packed partials are later
    going to be resampled. (*default*: `0.01`)
* **fade** (`float`): apply a fade to the partials before joining them.
    If not given, a default value is calculated (*default*: `-1.0`)
* **acceptabledist** (`float`): instead of searching for the best possible fit,
    pack         two partials together if they are near enough (*default*:
    `0.1`)
* **minbps** (`int`): the min. number of breakpoints for a partial to the
    packed. Partials         with less that this number of breakpoints are
    filtered out (*default*: `2`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[list[np.ndarray], list[np.ndarray]]`) a tuple (tracks, unpacked partials)


---------


## partial\_at


```python

def partial_at(p: np.ndarray, t: float, extend: bool = False
               ) -> np.ndarray | None

```


Evaluates partial `p` at time `t`



**Args**

* **p** (`np.ndarray`): the partial, a 2D numpy array
* **t** (`float`): the time to evaluate the partial at
* **extend** (`bool`): should the partial be extended to -inf, +inf? If True,
    querying a partial         outside its boundaries will result in the values
    at the boundaries.         Otherwise, None is returned (*default*: `False`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray | None`) with columns (time, freq, amp, bw). Returns None if the array is not defined at the given time


---------


## partial\_crop


```python

def partial_crop(p: np.ndarray, t0: float, t1: float) -> np.ndarray

```


Crop partial at times t0, t1


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


---------


## partial\_energy


```python

def partial_energy(partial: np.ndarray) -> float

```


Integrate the partial amplitude over time.


Serves as measurement for the energy contributed by the partial.

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

* **partial** (`np.ndarray`): the partial to calculate its energy from

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`float`) the energy of this partial (the integral of amplitude over time)


---------


## partial\_fade


```python

def partial_fade(partial: np.ndarray, fadein: float = 0.0, fadeout: float = 0.0
                 ) -> np.ndarray

```


Apply a fadein / fadeout to this partial so that the first and last


breakpoints have an amplitude = 0

This is only applied if the partial starts or ends in non-zero amplitude



**Args**

* **partial** (`np.ndarray`): the partial to fade
* **fadein** (`float`): the fadein time. If 0 and the first breakpoint has a
    non-zero         amplitude, zero the first amplitude in the partial
    (*default*: `0.0`)
* **fadeout** (`float`): the fadeout time. If 0 and the last breakpoint has a
    non-zero         aplitude, zero the last amplitude in the partial.
    (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) the faded partial


---------


## partial\_sample\_at


```python

def partial_sample_at(p: np.ndarray, times: np.ndarray) -> np.ndarray

```


Sample a partial `p` at given times



**Args**

* **p** (`np.ndarray`): a partial represented as a 2D-array with columns
    times, freqs, amps, phases, bws
* **times** (`np.ndarray`): the times to evaluate partial at

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) a partial (2D-array with columns times, freqs, amps, phases, bws)


---------


## partial\_sample\_regularly


```python

def partial_sample_regularly(p: np.ndarray, dt: float, t0: float = -1.0, 
                             t1: float = -1.0) -> np.ndarray

```


Sample a partial `p` at regular time intervals



**Args**

* **p** (`np.ndarray`): a partial represented as a 2D-array with columns
    `times, freqs, amps, phases, bws`
* **dt** (`float`): sampling period
* **t0** (`float`): start time of sampling (*default*: `-1.0`)
* **t1** (`float`): end time of sampling (*default*: `-1.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray`) a partial (2D-array with columns times, freqs, amps, phases, bws)


---------


## partial\_timerange


```python

def partial_timerange(partial: np.ndarray) -> tuple[float, float]

```


Return begin and endtime of partial



**Args**

* **partial** (`np.ndarray`): the partial to query

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[float, float]`) the start and end time


---------


## partials\_at


```python

def partials_at(partials: list[np.ndarray], t: float, maxcount: int = 0, 
                mindb: int = -120, minfreq: int = 10, maxfreq: int = 22000
                ) -> list[np.ndarray]

```


Sample the partials which satisfy the given conditions at time t



**Args**

* **partials** (`list[np.ndarray]`): the partials analyzed. The partials should
    be present at the         given time (after calling partials_between or
    PartialIndex.partials_between)
* **t** (`float`): the time in seconds
* **maxcount** (`int`): the max. partials to detect, ordered by amplitude
    (0=all) (*default*: `0`)
* **mindb** (`int`): the min. amplitude a partial has to have at `t` in order to
    be counted (*default*: `-120`)
* **minfreq** (`int`): only partials with a freq. higher than this (*default*:
    `10`)
* **maxfreq** (`int`): only partials with a freq. lower than this (*default*:
    `22000`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) the breakpoints at time t which satisfy the given conditions. Each breakpoint is a numpy array with [freq, amp, phase, bandwidth]


---------


## partials\_between


```python

def partials_between(partials: list[np.ndarray], t0: float = 0.0, 
                     t1: float = 0.0) -> list[np.ndarray]

```


Return the partials present between t0 and t1


This function is not optimized and performs a linear search over the
partials. If this function is to be called repeatedly or within a
performance relevant section, use `PartialIndex` instead



**Args**

* **partials** (`list[np.ndarray]`): a list of partials
* **t0** (`float`): start time in secs (*default*: `0.0`)
* **t1** (`float`): end time in secs (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) the partials within the time range (t0, t1)


---------


## partials\_render


```python

def partials_render(partials: list[np.ndarray], outfile: str, sr: int = 44100, 
                    fadetime: float = -1.0, start: float = -1.0, 
                    end: float = -1.0, encoding: str = None) -> None

```


Render partials as a soundfile


**See Also**: synthesize



**Args**

* **partials** (`list[np.ndarray]`): the partials to render
* **outfile** (`str`): the outfile to write to. If not given, a temporary file
    is used
* **sr** (`int`): samplerate to render with (*default*: `44100`)
* **fadetime** (`float`): fade partials in/out when they don't end in a 0-amp bp
    (*default*: `-1.0`)
* **start** (`float`): start time of render (default: start time of spectrum)
    (*default*: `-1.0`)
* **end** (`float`): end time to render (default: end time of spectrum)
    (*default*: `-1.0`)
* **encoding** (`str`): if given, the encoding to use (*default*: `None`)


---------


## partials\_sample


```python

def partials_sample(partials: list[np.ndarray], dt: float = 0.002, 
                    t0: float = -1, t1: float = -1, maxactive: int = 0, 
                    interleave: bool = True
                    ) -> np.ndarray | tuple[np.ndarray, np.ndarray, np.ndarray]

```


Samples the partials between times `t0` and `t1` with sampling period `dt`


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

* **partials** (`list[np.ndarray]`): a list of 2D-arrays, each representing a
    partial
* **dt** (`float`): sampling period (*default*: `0.002`)
* **t0** (`float`): start time, or None to use the start time of the spectrum
    (*default*: `-1`)
* **t1** (`float`): end time, or None to use the end time of the spectrum
    (*default*: `-1`)
* **maxactive** (`int`): limit the number of active partials to this number. If
    the         number of active streams (partials with non-zero amplitude) is
    higher than `maxactive`, the softest partials will be zeroed.         During
    resynthesis, zeroed partials are skipped.         This strategy is followed
    to allow to pack all partials at the cost         of having a great amount
    of streams, and limit the streams (for         better performance) at the
    synthesis stage. (*default*: `0`)
* **interleave** (`bool`): if True, all columns of each partial are interleaved
    (see below) (*default*: `True`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`np.ndarray | tuple[np.ndarray, np.ndarray, np.ndarray]`) if interleave is True, returns a big matrix where all partials are interleaved and present at all times. Otherwise returns three arrays, (freqs, amps, bws) where freqs represents the frequencies of all partials, etc. See below


---------


## partials\_save\_matrix


```python

def partials_save_matrix(partials: list[np.ndarray], outfile: str =, 
                         dt: float = None, gapfactor: float = 3.0, 
                         maxtracks: int = 0, maxactive: int = 0
                         ) -> tuple[list[np.ndarray], np.ndarray]

```


Packs short partials into longer partials and saves the result as a matrix


### Example

```python

import loristrck as lt
partials, labels = lt.read_sdif(sdiffile)
selected, rest = lt.util.select(partials, minbps=2, mindur=0.005, minamp=-80)
lt.util.partials_save_matrix(selected, 0.002, "packed.mtx")

```



**Args**

* **partials** (`list[np.ndarray]`): a list of numpy 2D-arrays, each
    representing a partial
* **outfile** (`str`): path to save the sampled partials. Supported formats:
    `.mtx`, `.npy`         (See matrix_save for more information). If not given,
    the matrix is not saved (*default*: ``)
* **dt** (`float`): sampling period to sample the packed partials. If not given,
    it will be estimated with sensible defaults. To have more control
    over this stage, you can call estimate_sampling_interval yourself.
    At the cost of oversampling, a good value can be ksmps/sr, which results
    in 64/44100 = 0.0014 secs for typical values (*default*: `None`)
* **gapfactor** (`float`): partials are packed with a gap = dt * gapfactor.
    It should be at least 2. A gap is a minimal amount of silence
    between the partials to allow for a fade out and fade in (*default*: `3.0`)
* **maxtracks** (`int`): Partials are packed in tracks and represented as a 2D
    matrix where         each track is a row. If filesize and save/load time are
    a concern,         a max. value for the amount of tracks can be given here,
    with the         consequence that partials might be left out if there are no
    available         tracks to pack them into. See also `maxactive` (*default*:
    `0`)
* **maxactive** (`int`): Partials are packed in simultaneous tracks, which
    correspond to         an oscillator bank for resynthesis. If maxactive is
    given,         a max. of `maxactive` is allowed, and the softer partials are
    zeroed to signal that they can be skipped during resynthesis. (*default*:
    `0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[list[np.ndarray], np.ndarray]`) a tuple (packed spectrum, matrix)


---------


## partials\_stretch


```python

def partials_stretch(partials: list[np.ndarray], factor: float, 
                     inplace: bool = False) -> list[np.ndarray]

```


Stretch the partials in time by a given constant factor



**Args**

* **partials** (`list[np.ndarray]`): a list of partials
* **factor** (`float`): float. a factor to multiply all times by
* **inplace** (`bool`): modify partials in place (*default*: `False`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) the stretched partials


---------


## partials\_timerange


```python

def partials_timerange(partials: list[np.ndarray]) -> tuple[float, float]

```


Return the timerange of the partials: (begin, end)



**Args**

* **partials** (`list[np.ndarray]`): the partials to query

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[float, float]`) with the corresponding times in seconds


---------


## partials\_transpose


```python

def partials_transpose(partials: list[np.ndarray], interval: float, 
                       inplace: bool = False) -> list[np.ndarray]

```


Transpose the partials by a given interval



**Args**

* **partials** (`list[np.ndarray]`): the partials to transpose
* **interval** (`float`): the interval in semitones
* **inplace** (`bool`): if True, the partials are modified in place. Otherwise
    a new partial list is returned (*default*: `False`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`list[np.ndarray]`) the modified partial list, or the original list modified in place


---------


## plot\_partials


```python

def plot_partials(partials: list[np.ndarray], downsample: int = 1, 
                  cmap: str = inferno, exp: float = 1.0, linewidth: int = 1, 
                  ax=None, avg: bool = True) -> Any

```


Plot the partials using matplotlib



**Args**

* **partials** (`list[np.ndarray]`): a list of numpy arrays, each representing a
    partial
* **downsample** (`int`): If > 1, only one every `downsample` breakpoints will
    be taken         into account. (*default*: `1`)
* **cmap** (`str`): a string defining the colormap used         (see
    <https://matplotlib.org/users/colormaps.html>) (*default*: `inferno`)
* **exp** (`float`): an exponential to apply to the amplitudes before plotting
    (*default*: `1.0`)
* **linewidth** (`int`): the line width of the plot (*default*: `1`)
* **ax**: A matplotlib axes. If one is passed, plotting will be done to this
    axes. Otherwise a new axes is created (*default*: `None`)
* **avg** (`bool`): if True, the colour of a segment depends on the average
    between the         amplitude at the start breakpoint and the end breakpoint
    of the segment         Otherwise only the amplitude of the start breakpoint
    is used (*default*: `True`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;a matplotlib axes


---------


## select


```python

def select(partials: list[np.ndarray], mindur: float = 0.0, minamp: int = -120, 
           maxfreq: int = 24000, minfreq: int = 0, minbps: int = 1, 
           t0: float = 0.0, t1: float = 0.0
           ) -> tuple[list[np.ndarray], list[np.ndarray]]

```


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



**Args**

* **partials** (`list[np.ndarray]`): a list of numpy 2D arrays, each array
    representing a partial
* **mindur** (`float`): min. duration (in seconds) (*default*: `0.0`)
* **minamp** (`int`): min. amplitude (in dB) (*default*: `-120`)
* **maxfreq** (`int`): max. frequency (*default*: `24000`)
* **minfreq** (`int`): min. frequency (*default*: `0`)
* **minbps** (`int`): min. breakpoints (*default*: `1`)
* **t0** (`float`): only partials defined after t0 (*default*: `0.0`)
* **t1** (`float`): only partials defined before t1 (*default*: `0.0`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[list[np.ndarray], list[np.ndarray]]`) (selected partials, discarded partials)


---------


## sndread


```python

def sndread(path: str, contiguous: bool = True) -> tuple[np.ndarray, int]

```


Read a sound file.



**Args**

* **path** (`str`): The path to the soundfile
* **contiguous** (`bool`): If True, it is ensured that the returned array
    is contiguous. This should be set to True if the samples are to be
    passed to `analyze`, which expects a contiguous array (*default*: `True`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[np.ndarray, int]`) a tuple (samples:np.ndarray, sr:int)


---------


## sndreadmono


```python

def sndreadmono(path: str, chan: int = 0, contiguous: bool = True
                ) -> tuple[np.ndarray, int]

```


Read a sound file as mono.


If the soundfile is multichannel, the indicated channel `chan` is returned.



**Args**

* **path** (`str`): The path to the soundfile
* **chan** (`int`): The channel to return if the file is multichannel
    (*default*: `0`)
* **contiguous** (`bool`): If True, it is ensured that the returned array
    is contiguous. This should be set to True if the samples are to be
    passed to `analyze`, which expects a contiguous array (*default*: `True`)

**Returns**

&nbsp;&nbsp;&nbsp;&nbsp;(`tuple[np.ndarray, int]`) a tuple (samples:np.ndarray, sr:int)


---------


## sndwrite


```python

def sndwrite(samples: np.ndarray, sr: int, path: str, encoding: str = None
             ) -> None

```


Write the samples to a soundfile



**Args**

* **samples** (`np.ndarray`): the samples to write
* **sr** (`int`): samplerate
* **path** (`str`): the outfile to write the samples to (the extension will
    determine the format)
* **encoding** (`str`): the encoding of the samples. If None, a default is used,
    according to         the extension of the outfile given. Otherwise, a string
    'floatXX' or 'pcmXX'         is expected, where XX represent the bits per
    sample (15, 24, 32, 64 for pcm,         32 or 64 for float). Not all
    encodings are supported by all formats. (*default*: `None`)


---------


## wavwrite


```python

def wavwrite(outfile: str, samples: np.ndarray, sr: int = 44100, bits: int = 32
             ) -> None

```


Write samples to a wav-file (see also sndwrite) as float32 or float64



**Args**

* **outfile** (`str`): the path of the output file
* **samples** (`np.ndarray`): the samples to write
* **sr** (`int`): the sample rate (*default*: `44100`)
* **bits** (`int`): the bit-width used when writing the samples (*default*:
    `32`)


---------


## write\_sdif


```python

def write_sdif(partials: list[np.ndarray], outfile: str, labels=None, 
               fmt: str = RBEP, fadetime: float = 0.0) -> None

```


Write a list of partials as SDIF.


!!! note

    The 1TRC format forces resampling, since all breakpoints within a 
    1TRC frame need to share the same timestamp. In the RBEP format
    a breakpoint has a time offset to the frame time stamp



**Args**

* **partials** (`list[np.ndarray]`): a seq. of 2D arrays with columns [time freq
    amp phase bw]
* **outfile** (`str`): the path of the sdif file
* **labels**: a seq. of integer labels, or None to skip saving labels
    (*default*: `None`)
* **fmt** (`str`): one of "RBEP" / "1TRC" (*default*: `RBEP`)
* **fadetime** (`float`):  (*default*: `0.0`)