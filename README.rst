LORISTRCK
=========

`loristrck` is a wrapper for the C++ partial-tracking library Loris.

It is written in cython and targets python 3. The source of the library is included 
as part of the project and does not need to be installed previously.


C++ Library Dependencies:
  * fftw3_

.. _fftw3: http://www.fftw.org


Additional Python Module Dependencies:
  * Cython
  * NumPy
  * pysndfile + libsndfile


Installation
============

OSX using homebrew
------------------

``loristrck`` is a C/C++ extension for python and needs a compiler present

::

    brew install fftw
    brew install libsndfile
    pip install numpy cython
    pip install loristrck

Linux
-----

::

    apt install libfftw3-dev libsndfile1-dev
    pip install numpy cython
    pip install loristrck


Windows
-------

* Install ``libsndfile`` from http://www.mega-nerd.com/libsndfile/#Download
* Install ``fftw3`` from http://www.fftw.org/install/windows.html
* Download the 32-bit binary package. Unzip to a directory of your choice. 
  Suggestion: ``C:\\src``. You should have then a folder ``C:\\src\\fftw`` 
* Put that directory in your PATH (Control Panel/System/Advanced/Environmental Variables/)
  
  ``python setup.py install -LC:\\my\\path\\to\\fftw``


At the command-line, do::

  git clone https://github.com/gesellkammer/loristrck 
  cd loristrck 
  pip install -r requirements.txt
  pip install .


Otherwise, install it via pip::

   pip install numpy cython
   pip install loristrck

(this assumes that you put the fftw3 source under ``C:\\src``)


Usage
=====

.. code-block:: python

   import loristrck as lt

   samples, sr = lt.sndreadmono("/path/to/sndfile.wav")
   partials = lt.analyze(samples, sr, resolution=60)
   # partials is a python list of numpy arrays
   for partial in partials:
       print(partial)


Each partial will be a numpy array of shape = (numbreakpoints, 5)
with the columns::

  time, frequency, amplitude, phase, bandwidth


See the example scripts in `bin` for more complete examples


See also
========

sndtrck: https://github.com/gesellkammer/sndtrck


Author
------

eduardo dot moguillansky @ gmail dot com

License
-------

GPL
