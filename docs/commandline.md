# Command-line utilities

*loristrck* provides a set of command-line utilities to analyze and transform 
spectra directly from the command-line

These utilities are installed alongside the *loristrck* python package

-----

## loristrck_analyze

Partial tracking analysis. Takes a soundfile as input and generates a 
SDIF file of 1TRC or RBEP format

```bash

usage: loristrck_analyze [OPTIONS] sndfile

```

### Options

* `-r RESOLUTION` / `--resolution RESOLUTION`: Only one partial will be found within this distance. 
	Usual values range from 30 Hz to 200 Hz. As a rule of thumb, when tracking a
    monophonic source, `resolution ~= min(f0) * 0.9`. So if the source is a male 
    voice dropping down to 70 Hz, resolution=60 Hz. The resolution determines the size of the fft
* `-w WINSIZE` / `--winsize WINSIZE`: Hz. Is the main lobe width of the Kaiser analysis window in Hz 
	(main-lobe, zero to zero). If not given, a default value is calculated. In general window size 
	should be higher than the resolution (default = `resolution*2`)
* `--hoptime HOPTIME`: The time to shift the window after each analysis (default: 1/windowsize, which
	results in 1x overlap). For 4x overlap and a window size of 60 Hz, hoptime should be 0.00417.
	See also `--hopoverlap`
* `--hopoverlap OVERLAP`: If given, sets the hoptime in terms of overlapping windows. A hop overlap 
	of 2 will result in a `hop time = 1/(2*windowsize)`
* `--ampfloor AMPFLOOR`: min. amplitude of any breakpoint, in dB (default = -120)
* `--freqdrift FREQ`: Hz. The maximum variation of frecuency between two breakpoints to be
            considered to belong to the same partial. A sensible value is
            between 1/2 to 3/4 of resolution: `freqdrift=0.62*resolution`
* `--sidelobe SIDELOBE`: dB (default: 90 dB). A positive dB value, indicates the shape of the Kaiser window
* `--residuebw RESIDUE`: Hz (default = 2000 Hz). Construct Partial bandwidth env. by associating 
    residual energy with the selected spectral peaks that are used to construct Partials.
    The bandwidth is the width (in Hz) association regions used.
    Defaults to 2 kHz, corresponding to 1 kHz region center spacing.
* `--croptime TIME`: sec. Max. time correction beyond which a reassigned bp is considered 
    unreliable, and not eligible. Default: the hop time. 
* `--outfile OUTFILE`: The generated sdif file
* `--sdiftype SDIFTYPE`: One of 'rbep' or '1trk' (case is ignored)
* `--minbps MINBPS`: Min. number of breakpoints for a partial to not be discarded
* `--minamp MINAMP`: Min. amplitude of a partial (in average) to not be discarded
* `--fadetime FADETIME`: fade time used when a partial does not end with a 0 amp breakpoint

-----

## loristrck_pack

Analyzes a soundfile or loads a previously analyzed sdiffile, packing the
partials into a number of simultaneous streams, in order to be resynthesized.

The result is a matrix of at most `maxoscil*3` number of columns, the height of the
matrix being dependent on the length of the sound and the sampling interval used.

The matrix is saved as an uncompressed .wav file with the format:

	Header: [dataOffset=5, dt, numcols, numrows, t0] 

And then the data, a matrix of numcols x numrows, where:

    numcols = numstreams * 3
              (each stream consists of three columns: freq, amp and bandwidth)
    numrows = each row consists of a sample at time t, where t = t0 + row*dt

This is mostly thought to be used in tandem with csound's beadsynt opcode,
which performs band-enhanced-additive-synthesis in realtime

!!! note
	If you need more control over the analysis step, first analyze the soundfile
    to obtain a sdif file, then use this utility to pack a matrix
    (see loristrck_analyze)


```bash

positional arguments
--------------------

infile: An infile can be a soundfile or a sdif file

optional arguments
------------------

-h, --help            show this help message and exit
-r RESOLUTION, --resolution RESOLUTION
                    Analysis resolution, in Hz (only for analysis)
-w WINSIZE, --winsize WINSIZE
                    Window size (in Hz) (only valid if doing analysis)
-o OUTFILE, --outfile OUTFILE
                    Name of the resulting wav file
--minbps MINBPS       Min. number of breakpoints for a partial to be packed
--minamp MINAMP
--mindur MINDUR
--maxoscil MAXOSCIL   default=infinite
--maxtracks MAXTRACKS
                    Max. number of tracks (leave as 0 if table size is not a problem)
--dt DT               A sampling interval, in seconds. As a rule of thumb, 
                    dt should be somewhat smaller than ksmps/sr
```

-----

## loristrck_synth

Synthesize a .sdif or .mtx file

A `.sdif` file is the result of performing analysis, and can be any RBEP or 1TRC sdif file,
as produced, for example, via loristrck_analyze

A `.mtx` file is a packed spectrum, where partials are packed in non-simultaneous tracks
to produce facilitate playback. See `loristrck_pack` for more information

```bash

usage: loristrck_synth [-h] [--speed SPEED] [--transposition TRANSPOSITION] [--noise {uniform,gaussian}]
                       [--quality QUALITY] [-o OUT]
                       inputfile

positional arguments:
  inputfile             A .sdif or .mtx file (as generated via loristrck_pack

optional arguments:
  -h, --help            show this help message and exit
  --speed SPEED         Playback speed. Pitch is not modified
  --transposition TRANSPOSITION
                        Transposition in semitones (independent from playback speed)
  --noise {uniform,gaussian}
                        Noise type used for the residual part when synthesizing a .mtx file. The original
                        implementation uses gaussian noise
  --quality QUALITY     Oscillator quality when playing a .mtx file. 0: fast, 1: fast + freq. interpolation, 2:
                        linear interpolation, 3: linear interpolation + freq. interpolation
  -o OUT, --out OUT     Play / Save the samples. Use dac to play in realtime (.mtx files only), or a .wav of .aif
                        path to synthesize to that file

```

-----

## loristrck_chord

Extract a chord from a soundfile at a given time

```bash
usage: loristrck_chord [OPTIONS] sdiffile

TODO

positional arguments:
  sdiffile              The input file, a sdif file with format 1TRC or RBEP

optional arguments:
  -h, --help            show this help message and exit
  -t TIME, --time TIME  Time to extract the chord
  -n MAXCOUNT, --maxcount MAXCOUNT
                        Max. number of partials
  -a MINAMP, --minamp MINAMP
                        Min. amplitude of a breakpoint to be considered (in dB)
  -d MINDUR, --mindur MINDUR
                        Min. dur of a partial to be considered
  --minfreq MINFREQ     Min. freq of a partial
  --maxfreq MAXFREQ     Max. freq of a partial
  --sortby {frequency,amplitude}
  -s SOUND, --sound SOUND
                        Play / Generate a soundfile with the extracted chord. 
                        Use 'dac' to play directly
  --sounddur SOUNDDUR   Duration of the generated sound output
  --fade FADE
  --a4 A4               Reference frequency (default = 442 Hz)

```