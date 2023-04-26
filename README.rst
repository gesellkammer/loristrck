LORISTRCK
=========

|sh-downloads| |sh-month|

.. |sh-downloads| image:: https://static.pepy.tech/badge/loristrck
.. |sh-month| image:: https://static.pepy.tech/badge/loristrck/month


`loristrck` is a wrapper for the C++ partial-tracking library Loris.

It is written in cython and targets python 3 (>= 3.8 at the moment).
The source of the library is included as part of the project and
does not need to be installed previously.


Documentation
-------------


https://loristrck.readthedocs.io

---------------


Installation
------------


.. code-block:: bash

    pip install loristrck


Install from source in Windows
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You need to have Visual Studio installed


.. code-block:: bash


    # From a Developer Powershell
    python scripts/prepare_windows_build.py

    # From a normal prompt
    pip install .


---------------


Usage
-----

.. code-block:: python


   import loristrck as lt

   samples, sr = lt.sndreadmono("/path/to/sndfile.wav")
   partials = lt.analyze(samples, sr, resolution=60)
   # partials is a python list of numpy arrays
   # select a subset of most significant partials
   selected, noise = lt.select(partials, mindur=0.02, maxfreq=12000, minamp=-60, minbp=2)
   # print each partial as data
   for partial in selected:
       print(partial)
   # plot selected partials
   lt.plot_partials(selected)
   # now resynthesize both parts separately 
   lt.partials_render(selected, outfile="selected.wav")
   lt.partials_render(noise, outfile="noise.wav")
   

Each partial will be a numpy array of shape = (numbreakpoints, 5)
with the columns::

  time, frequency, amplitude, phase, bandwidth


See the example scripts in `bin` for more complete examples


Author
~~~~~~

Eduardo Moguillansky

eduardo dot moguillansky @ gmail dot com


License
~~~~~~~

GPL
