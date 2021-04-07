# Reference

The functions documented here are implemented in cython and interact directly with
the underlying C++ code in *Loris*. 

!!! info

    See also [loristrck.util](util.md) for supporting utilities regarding transformation 
    of partials, rendering, plotting, etc.

-----


## analyze


```python
def analyze(samples: np.ndarray, 
            sr: float, 
            resolution: float, 
            windowsize: float = None,
            hoptime: float = None, 
            freqdrift: float = None, 
            sidelobe: float = None,
            ampfloor: float = -90, 
            croptime: float = None, 
            residuebw: float = None, 
            convergencebw: float = None,
            outfile: str = None
            ) -> list[np.ndarray]
```

**Partial Tracking Analysis**

Analyze the audio samples. Returns a list of 2D numpy arrays, where each array 
represent a partial with columns: `[time, freq, amplitude, phase, bandwidth]`
If outfile is given, a sdif file is saved with the results of the analysis

There are three categories of analysis parameters:
    - the resolution and params related to it (freq. floor and drift)
    - the window width and params related to it (hop and crop times)
    - independent parameters (bw region width and amp floor)

### Args

* **samples**: numpy.ndarray
    An array representing a mono sndfile.   
* **sr**: int (Hz)
    The sampling rate
* **resolution**: Hz 
    Only one partial will be found within this distance. 
    Usual values range from 30 Hz to 200 Hz. As a rule of thumb, when tracking a
    monophonic source, resolution ~= min(f0) * 0.9
    So if the source is a male voice dropping down to 70 Hz, resolution=60 Hz 
* **windowsize**: Hz.
    Is the main lobe width of the Kaiser analysis window in Hz (main-lobe, zero to zero)
    If not given, a default value is calculated. 
    The size of the window in samples can be calculated by:
    util.kaiserLength(windowsize, sr, sidelobe)
* **hoptime**: sec
    The time to move the window after each analysis. 
    Default: 1/windowsize. "hop time in secs is the inverse of the window width
    really. A good choice of hop is the window length divided by the main lobe width 
    in freq. samples, which turns out to be just the inverse of the width."
    A lower hoptime can be used: for instance a 2x overlap would result in a hoptime
    of hoptime=1/windowsize*0.5
    NB: when using overlap, croptime should still be 1/windowsize
* **freqdrift**: Hz
    The maximum variation of frecuency between two breakpoints to be
    considered to belong to the same partial. A sensible value is
    between 1/2 to 3/4 of resolution: freqdrift=0.62*resolution
* **sidelobe**: dB (default: 90 dB)
    A positive dB value, indicates the shape of the Kaiser window
* **ampfloor**: dB
    A breakpoint with an amp < ampfloor can't be part of a partial
* **croptime**: sec 
    Max. time correction beyond which a reassigned bp is considered 
    unreliable, and not eligible. Default: the hop time. 
* **residuebw**: Hz (default = 2000 Hz)
    Construct Partial bandwidth env. by associating residual energy with 
    the selected spectral peaks that are used to construct Partials.
    The bandwidth is the width (in Hz) association regions used.
    Defaults to 2 kHz, corresponding to 1 kHz region center spacing.
    NB: if residuebw is set, convergencebw must be left unset
* **convergencebw**: range `[0, 1]`
    Construct Partial bandwidth env. by storing the 
    mixed derivative of short-time phase, scaled and shifted.  
    The value is the amount of range over which the mixed derivative 
    indicator should be allowed to drift away from a pure sinusoid 
    before saturating. This range is mapped to bandwidth values on
    the range `[0,1]`.  
    NB: one can set residuebw or convergencebw, but not both
    

### Returns

A list of partials, where each partial is a numpy array of shape `(number of breakpoints, 5)`
The format for each partial is:

| Col 0  | Col 1  | Col 2 | Col 3   | Col 4 |
| ----   | ------ | ----  | ----    | ----  |
| time_0 | freq_0 | amp_0 | phase_0 | bw_0  |
| time_1 | freq_1 | amp_1 | phase_1 | bw_1  |
| ...    | ...    | ...   | ...     | ...   |
| time_n | freq_n | amp_n | phase_n | bw_n  |

### Example

``` python

import loristrck as lt
import numpy as np

# Read a soundfile as a numpy array
samples, sr = lt.sndreadmono("voice.wav")

# Analyze the soundfile with a frequency resolution of 30 Hz and 
# a window size of 40 Hz. A hoptime of 1/120 will result in 4x overlap
partials = lt.analyze(samples, sr, resolution=30, windowsize=40, 
                      hoptime=1/120)
                      
# for each partial, calculate the mean weighted frequency
def mean_weighted_freq(partial):
    return np.mean(partial[:,1] * partail[:,2])

freqs = [mean_weighted_freq(partial) for partial in partials]
for i, partial in enumerate(partials):
    freq = mean_weighted_freq(partial)
    print(f"Partial #{i}, start time: {partial[0, 0]}, mean freq.: freq}")

# Save the analysis as a .sdif file with RBEP format
lt.write_sdif(partials, "analysis.sdif")

```

------------------------------------

## read_sdif

Read a `SDIF` file (`1TRC` or `RBEP`)

``` python
def read_sdif(path: str
             ) -> tuple[list[np.ndarray], list[int]]
```

#### Args
* **path**: The path of the `.sdif` file to read

#### Returns
    
A tuple (*list of partials*, *labels*), where a partial is a 2D numpy array with a shape
(*number of breakpoints*, 5).

------------------------------------

## write_sdif

``` python
def write_sdif(partials: list[np.ndarray], 
               outfile: str, 
               labels:list[int] | None, 
               rbep=True, 
               fadetime=0.
               ) -> None
```

Write a list of partials in the sdif

#### Args

* **partials**: a seq. of 2D arrays with columns [time freq amp phase bw]
* **outfile**: the path of the sdif file
* **labels**: a seq. of integer labels, or None to skip saving labels
* **rbep**: if True, use RBEP format, otherwise, 1TRC

!!! Note

    The 1TRC format forces resampling

--------------------------------------

## read_aiff

Read a mono AIFF file (Loris does not read stereo files)

``` python

def read_aiff(path: str
             ) -> tuple[audiodata: np.ndarray, samplerate: int]
```

#### Args

* **path** (`str`): The path to the soundfile (`.aif` or `.aiff`)

#### Returns

A tuple (audiodata: np.ndarray, samplerate: int)

!!! Warning

    This function will raise `ValueError` if the soundfile is not mono
    
-------------------------------

## synthesize

Synthesizes a list of partials, returns the generated audio samples as 1D numpy array

``` python
def synthesize(partials: list[np.ndarray],
               samplerate: int,
               fadetime: float = None,
               start: float = None,
               end: float = None
               ) -> np.ndarray
```

#### Args

* **partials** (`list[np.ndarray]`): a list of partials, where each partial is a 
  2D numpy array
* **samplerate** (int): the samplerate of the synthesized samples (in Hz)
* **fadetime** (float): to avoid clicks, partials not ending in 0 amp should be 
  faded. If not given a sensible default is used. A minimum fadetime is always applied, 
  even if 0 is given.
* **start** (float): start time of synthesis (in seconds).
* **end** (float): end time of synthesis

#### Returns

The sampes generated, as a 1D numpy array.

#### Example

Synthesize and play partials from a previously analyzed sound

``` python

import loristrck as lt
import sounddevice as sd
partials, labels = lt.read_sdif("analysis.sdif")
samples = lt.synthesize(partials, 44100)
sd.play(samples, 44100)

```

-------------------------------

## estimatef0

Estimate the fundamental of a previously analyzed sound

``` python

def estimatef0(partials: list[np.ndarray, 
               minfreq: float, 
               maxfreq: float,
               interval: float  
               ) -> tuple[freqs: np.ndarray, 
                          confidencies: np.ndarray, 
                          starttime: float, 
                          endtime: float]
```

#### Args

* **partials** (`list[np.ndarray]`): the partials to analyze to determine the fundamental
* **minfreq** (`float`): the min. frequency to considere as a fundamental
* **maxfreq** (`float`): the max. frequency to considere as a fundamental
* **interval** (`float`): the time resolution of the fundamental curve

#### Returns

A tuple (*freqs*, *confidencies*, *starttime*, *endtime*). 

* **freqs** (`np.ndarray`): an array with the frequencies representing the fundamental in time
* **confidencies** (`np.ndarray`): for each frequency there is a corresponding confidency value
  determining the confidence on this value being the correct f0
* **starttime**: the start time of the fundamental
* **endtime**: the endtime of the fundamental. 

To determine the time for each frequency measurement of the f0, do: 

``` python
times = np.linspace(starttime, endtime, len(freqs))
```

-------------------------------

## meancol

Calculates the mean over a given column of a 2D np.ndarray. 

``` python
def meancol(X: np.ndarray, col: int) -> float

```

#### Args

* **X**: a 2D numpy array
* **col**: the index of the column to calculate the average for

#### Returns

The average over the given column

-------------------------------

## meancolw

Calculate the weighted mean over a given column and using another column as the weights

``` python
def meancol(X: np.ndarray, col: int, colw: int
            ) -> float

```

#### Args

* **X**: a 2D numpy array
* **col**: the index of the column to calculate the average for
* **colw**: the index of the column to use as weight

#### Returns

The weighted average over the given column

#### Example

Calculate the weighted average frequency of a given partial

``` python

import loristrck as lt
partials, labels = lt.read_sdif("analysis.sdif")
for i, partial in enumerate(partials):
    # average frequency using amplitude as weight
    freq = lt.meancolw(partial, 1, 2)
    print(f"Partial #{i}, avg. freq: {fre} Hz")
```

---------------------------------


