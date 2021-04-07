# loristrck.util



## concat

Concatenate multiple Partials to produce a new one.

```python

def concat(partials: list[np.ndarray], fade=0.005, edgefade=0.0
           ) -> np.ndarray

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

a numpy array representing the concatenation of the given partials

----------


## partial_at

Evaluates partial `p` at time `t`

```python

def partial_at(p: np.ndarray, t: float, extend=False
               ) -> np.ndarray

```


**Args**

* **p** (`np.ndarray`): the partial, a 2D numpy array
* **t** (`float`): the time to evaluate the partial at
* **extend** (`bool`): should the partial be extended to -inf, +inf? If True,
    querying a partial outside its boundaries will result in the values at the
    boundaries. Otherwise, None is returned (default: False)

**Returns**

the breakpoint at t (a np array of shape (4,) with columns (time, freq, amp, bw)

----------


## partial_crop

Crop partial at times t0, t1

```python

def partial_crop(p: np.ndarray, t0: float, t1: float
                 ) -> np.ndarray

```


**Args**

* **p** (`np.ndarray`): the partial
* **t0** (`float`): the start time
* **t1** (`float`): the end time

**Returns**

the cropped partial (raises ValueError if the partial is not defined
    within the given time constraints)

!!! note

    * Returns p if p is included in the interval t0-t1
    * Returns None if partial is not defined between t0-t1
    * Otherwise crops the partial at t0 and t1, places a breakpoint
      at that time with the interpolated value

----------


## partials_sample

Samples the partials between times `t0` and `t1` with a sampling

```python

def partials_sample(sp: list[np.ndarray], dt=0.002, t0: float = -1, 
                    t1: float = -1, maxactive=0, interleave=True)
                    ) -> None

```
period `dt`.

**Args**

* **sp** (`List[np.ndarray]`): a list of 2D-arrays, each representing a partial
* **dt** (`float`): sampling period (default: 0.002)
* **t0** (`float`): start time, or None to use the start time of the spectrum
    (default: -1)
* **t1** (`float`): end time, or None to use the end time of the spectrum
    (default: -1)
* **maxactive** (`int`): limit the number of active partials to this number. If
    the number of active streams (partials with non-zero amplitude) if higher
    than `maxactive`, the softest partials will be zeroed. During resynthesis,
    zeroed partials are skipped. This strategy is followed to allow to pack all
    partials at the cost of having a great amount of streams, and limit the
    streams (for better performance) at the synthesis stage. (default: 0)
* **interleave** (`bool`): if True, all columns of each partial are interleaved
    (see below) (default: True)

**Returns**

if interleave is True, returns a big matrix where all partials are interleaved
    and present at all times. Otherwise returns three arrays, (freqs, amps, bws)
    where freqs represents the frequencies of all partials, etc. See below

To be used in connection with `pack`, which packs short non-simultaneous
partials into longer ones. The result is a 2D matrix representing the partials.

Sampling times is calculated as: times = arange(t0, t1+dt, dt)

If interleave is True, it returns a big matrix of format

```python

[[f0, amp0, bw0, f1, amp1, bw1, …, fN, ampN, bwN],   # times[0]
 [f0, amp0, bw0, f1, amp1, bw1, …, fN, ampN, bwN],   # times[1]
 ...
]
```

Where (f0, amp0, bw0) represent the freq, amplitude and bandwidth
of partial 0 at a given time, (f1, amp1, bw0) the corresponding data
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

----------


## meanamp

Returns the mean amplitude of a partial

```python

def meanamp(partial: np.ndarray
            ) -> float

```


**Args**

* **partial** (`np.ndarray`): a numpy 2D-array representing a Partial

**Returns**

the average amplitude

----------


## meanfreq

Returns the mean frequency of a partial, optionally

```python

def meanfreq(partial: np.ndarray, weighted=False
             ) -> float

```
weighting this mean by the amplitude of each breakpoint

**Args**

* **partial** (`np.ndarray`):
* **weighted** (`bool`):  (default: False)

----------


## partial_energy

Integrate the partial amplitude over time. Serves as measurement

```python

def partial_energy(partial: np.ndarray
                   ) -> float

```
for the energy contributed by the partial.

**Args**

* **partial** (`np.ndarray`):

----------


## select

Selects a seq. of partials matching the given conditions

```python

def select(partials: list[np.ndarray], mindur=0.0, minamp=-120, maxfreq=24000, 
           minfreq=0, minbps=1, t0=0.0, t1=0.0
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

(selected partials, discarded partials)

----------


## filter

Similar to select, but returns a generator yielding only selected partials

```python

def filter(partials: list[np.ndarray], mindur=0.0, mindb=-120, maxfreq=2400, 
           minfreq=0, minbps=1, t0=0.0, t1=0.0)
           ) -> None

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


## sndreadmono

Read a sound file as mono. If the soundfile is multichannel,

```python

def sndreadmono(path: str, chan: int = 0, contiguous=True
                ) -> tuple[np.ndarray, int]

```
the indicated channel `chan` is returned.

**Args**

* **path** (`str`): The path to the soundfile
* **chan** (`int`): The channel to return if the file is multichannel (default:
    0)
* **contiguous** (`bool`): If True, it is ensured that the returned array  is
    contiguous. This should be set to True if the samples are to be passed to
    `analyze`, which expects a contiguous array (default: True)

**Returns**

a tuple (samples:np.ndarray, sr:int)

----------


## sndwrite

Write the samples to a soundfile

```python

def sndwrite(samples: np.ndarray, sr: int, path: str, encoding=None
             ) -> None

```


**Args**

* **samples** (`np.ndarray`): the samples to write
* **sr** (`int`): samplerate
* **path** (`str`): the outfile to write the samples to (the extension will
    determine the format)
* **encoding** (`NoneType`): the encoding of the samples. If None, a default  is
    used, according to the extension of the outfile given. Otherwise, a  tuple
    like `('float', 32)` or `('pcm', 24)` is expected. Not all encodings  are
    supported by each format (default: None)

----------


## plot_partials

Plot the partials using matplotlib

```python

def plot_partials(partials: t.list[np.ndarray], downsample: int = 1, 
                  cmap='inferno', exp=1.0, linewidth=1, ax=None, avg=True)
                  ) -> None

```


**Args**

* **partials** (`t.List[np.ndarray]`): a list of numpy arrays, each representing
    a partial
* **downsample** (`int`): If > 1, only one every `downsample` breakpoints will
    be taken into account. (default: 1)
* **cmap** (`str`): a string defining the colormap used (see
    https://matplotlib.org/users/colormaps.html) (default: inferno)
* **exp** (`float`):  (default: 1.0)
* **linewidth** (`int`):  (default: 1)
* **ax** (`NoneType`): A matplotlib axes. If one is passed, plotting will be
    done to this axes. Otherwise a new axes is created (default: None)
* **avg** (`bool`):  (default: True)

**Returns**

a matplotlib axes

----------


## kaiser_length

Returns the length in samples of a Kaiser window from the desired main lobe width.

```python

def kaiser_length(width: float, sr: int, atten: int
                  ) -> int

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

the length of the window, in samples

----------


## partials_stretch

Stretch the partials in time by a given constant factor

```python

def partials_stretch(partials: list[np.ndarray], factor: float, inplace=False
                     ) -> list[np.ndarray]

```


**Args**

* **partials** (`List[np.ndarray]`): a list of partials
* **factor** (`float`): float a factor to multiply all times by
* **inplace** (`bool`): modify partials in place (default: False)

**Returns**

the stretched partials

----------


## partials_transpose

Transpose the partials by a given interval

```python

def partials_transpose(partials: list[np.ndarray], interval: float, 
                       inplace=False
                       ) -> list[np.ndarray]

```


**Args**

* **partials** (`List[np.ndarray]`):
* **interval** (`float`):
* **inplace** (`bool`):  (default: False)

----------


## partials_between

Return the partials present between t0 and t1

```python

def partials_between(partials: list[np.ndarray], t0=0.0, t1=0.0
                     ) -> list[np.ndarray]

```


**Args**

* **partials** (`List[np.ndarray]`): a list of partials
* **t0** (`float`): start time in secs (default: 0.0)
* **t1** (`float`): end time in secs (default: 0.0)

**Returns**

the partials within the time range (t0, t1)

----------


## partials_at

Return the breakpoints at time t which satisfy the given conditions

```python

def partials_at(partials: list[np.ndarray], t: float, maxcount=0, mindb=-120, 
                minfreq=10, maxfreq=22000, listen=False)
                ) -> None

```


**Args**

* **partials** (`List[np.ndarray]`): the partials analyzed
* **t** (`float`): the time in seconds
* **maxcount** (`int`): the max. partials to detect, ordered by amplitude
    (0=all) (default: 0)
* **mindb** (`int`):  (default: -120)
* **minfreq** (`int`):  (default: 10)
* **maxfreq** (`int`):  (default: 22000)
* **listen** (`bool`): if True, renders the extracted chord as a soundfile and
    opens it in an external application, for listening (default: False)

**Returns**

the breakpoints at time t which satisfy the given conditions

----------


## partials_render

Render partials as a soundfile

```python

def partials_render(partials: list[np.ndarray], outfile: str, sr=44100, 
                    fadetime=-1.0, start=-1.0, end=-1.0, encoding: str = None, 
                    open=False)
                    ) -> None

```


**Args**

* **partials** (`List[np.ndarray]`):
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
* **open** (`bool`): open the rendered file in the default application (default
    to True if no outfile is given) (default: False)

**Returns**

the path to the oufile written
