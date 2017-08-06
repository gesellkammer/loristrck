=========
LORISTRCK
=========

This is the simplest wrapper possible for the partial-tracking library Loris. 
The source of the library is included as part of the project, so there is no need
to install the library independently. 

C++ Library Dependencies:
  * fftw3_

.. _fftw3: http://www.fftw.org


Additional Python Module Dependencies:
  * Python (>= 2.7.*)
  * Cython_
  * NumPy
  * SciPy

.. _Cython: http://cython.org


Installation
------------

1) If you haven't, install FFTW3. Loris depends on it to perform in an acceptable way
    * OSX
        + the best alternative is to install via homebrew
    * Linux
        + you probably already have fftw3
    * Windows
        + go to http://www.fftw.org/install/windows.html
        + download the 32-bit binary package
        + unzip to a directory of your choice. 
          Suggestion: `C:\src`. You should have then a folder `C:\src\fftw` 
        + put that directory in your PATH 
          (Control Panel/System/Advanced/Environmental Variables/)
        + If you unzipped to any folder other than `C:\src`, pass that directory to
          the setup.py script as `python setup.py install -LC:\my\path\to\fftw`


2) To build and install everything, from the root folder run:

::

    $ python setup.py install
    
Usage
-----

::

    from loristrck import analyze
    sndfile = read_sndfile("/path/to/mono_sndfile.wav")
    partials = analyze(sndfile.samples, sndfile.sr, resolution=50, window_width=80)
    for label, data in partials:
        print data

data will be a numpy array of shape = (numframes, 5) with the columns::

  time . frequency . amplitude . phase . bandwidth

Goal
----

The main goal was as an analysis tool for the package `sndtrck`, which implements
an agnostic data structure to handle partial tracking information. So if `sndtrck`
is installed, it can be used as::

    >>> import sndtrck
    >>> spectrum = sndtrck.analyze_loris("/path/to/sndfile", resolution=50)
    >>> print spectrum.chord_at(0.5)
    [A3+, C5+10, E5-13]
    >>> spectrum.plot()  # this will generate a matplotlib plot of the partials

Credits
-------

eduardo dot moguillansky @ gmail dot com
