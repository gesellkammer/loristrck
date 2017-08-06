=========
LORISTRCK
=========

`loristrck` is a simple python wrapper for the C++ partial-tracking library Loris. It is written in cython and targets python 3.
The source of the library is included as part of the project installed alongside to avoid version mismatches


C++ Library Dependencies:
  * fftw3_

.. _fftw3: http://www.fftw.org


Additional Python Module Dependencies:
  * Python 3
  * Cython_
  * NumPy
  * SciPy
  * pysndfile + libsndfile (optional)

.. _Cython: http://cython.org


Installation
------------

1) If you haven't, install FFTW3. Loris depends on it to perform in an acceptable way

* OSX
    + the best alternative is to install via homebrew
* Linux
    + you probably already have fftw3. If not, install through your package manager.
    + For Ubuntu: `sudo apt install libfftw3-dev`
* Windows
    + go to http://www.fftw.org/install/windows.html
    + download the 32-bit binary package
    + unzip to a directory of your choice. 
      Suggestion: `C:\\src`. You should have then a folder `C:\\src\\fftw` 
    + put that directory in your PATH 
      (Control Panel/System/Advanced/Environmental Variables/)
    + If you unzipped to any folder other than `C:\\src`, pass that directory to
      the setup.py script as `python setup.py install -LC:\\my\\path\\to\\fftw`


2) Download and install

::

   git clone https://github.com/gesellkammer/loristrck
   cd loristrck
   pip install -r requirements.txt
   pip install .



Usage
-----

::
   import pysndfile
   import loristrck

   sndfile = pysndfile.PySndfile("/path/to/monosnd.wav")
   samples = sndfile.read_frames()
   sr = samplerate()
   partials = loristrck.analyze(samples, sr, resolution=40)
   # partials is a python list of numpy arrays
   for partial in partials:
       print(partial)


Each partial will be a numpy array of shape = (numbreakpoints, 5)
with the columns::

  time . frequency . amplitude . phase . bandwidth


Author
------

eduardo dot moguillansky @ gmail dot com
