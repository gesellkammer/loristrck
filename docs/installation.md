# Installation

## Dependencies

The external dependencies are:

* fftw
* libsndfile

----

## macOS

```bash
brew install fftw
brew install libsndfile
pip install loristrck
```

----

## Linux

```bash
sudo apt install libfftw3-dev libsndfile1-dev
pip install loristrck
```

----

## Windows

* Install ``libsndfile`` from http://www.mega-nerd.com/libsndfile/#Download
* Install ``fftw3`` from http://www.fftw.org/install/windows.html
* Unzip to a directory of your choicc (suggestion: ``C:\\src``). You should have a folder ``C:\\src\\fftw`` 
* Put that directory in your PATH (Control Panel/System/Advanced/Environmental Variables/)

```
pip install loristrck

```

The ``loris`` library is included and compiled into the cython bindings.

