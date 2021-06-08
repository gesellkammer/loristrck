import string
import shutil
import os
import sys
import subprocess
import tempfile


def jack_is_running() -> bool:
    jack_control = shutil.which("jack_control")
    if not jack_control:
        return False
    proc = subprocess.Popen([jack_control, "status"],
                            stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    return proc.wait() == 0


def play_mtx(mtxfile: str, out: str, speed=1., gain=1., freqscale=1., 
             noisetype='gaussian', linearinterp=True, freqinterp=False,
             ksmps=128, sr=44100, blocking=True):
    """
    Play a spectrum packed in a mtx file

    This needs csound >= 6.15 and csound plugins installed
    (https://github.com/csound-plugins/csound-plugins/releases)

    Args:
        mtxfile: the path to the mtx file
        out: the output file (a .wav or .aif file) or 'dac' for realtime
        speed: playback speed (will not affect pitch)
        freqscale: frequency scaling
        noisetype: noise shape for the residual part. One of 'gaussian'
            or 'uniform'
        linearinterp: if True, the oscillator performs linear interpolation
            between samples
        freqinterp: if True, the oscillator interpolates between freq. values
        ksmps: samples per cycle. 
        sr: sample rate when synthesizing to a file. For realtime, the 
            system sample rate is used
        blocking: if True, this function blocks until playback is finished. Otherwise
            the created subprocess is run in the background and the Popen 
            object is returned
        
    Returns:
        None if blocking; otherwise, the csound subprocess as subprocess.Popen object 

    """
    csoundbin = shutil.which("csound")
    if not csoundbin:
        raise RuntimeError("Csound should be installed in order to play a .mtx file")
    
    if not os.path.exists(mtxfile):
        raise OSError(f"mtx file {mtxfile} not found")

    flag = 0
    if noisetype == 'gaussian':
        flag += 1
    if linearinterp:
        flag += 2
    if freqinterp:
        flag += 4

    rtbackend = 'pa_cb'
    nchnls = 1
    if out == "dac":
        nchnls = 2
        if sys.platform == 'linux':
            if jack_is_running():
                rtbackend == 'jack'

    template = string.Template(r"""
<CsoundSynthesizer>
<CsOptions>
-o$out
-+rtaudio=$rtbackend
</CsOptions>
<CsInstruments>

sr = $sr
ksmps = $ksmps
nchnls = $nchnls
0dbfs = 1.0

gispectrum ftgen 0, 0, 0, -1, "$mtxfile", 0, 0, 0

instr 1
  ifn = gispectrum
  iskip      tab_i 0, ifn
  inumrows   tab_i 1, ifn
  inumcols   tab_i 2, ifn
  it0 = tab_i(iskip, ifn)
  it1 = tab_i(iskip+inumcols, ifn)
  idt = it1 - it0
  inumpartials = (inumcols-1) / 3 
  imaxrow = inumrows - 2
  it = ksmps / sr
  igain init $gain
  ispeed init $speed
  idur = imaxrow * idt / ispeed
  ifreqscale init $freqscale
  
  kt timeinsts
  kplayhead = phasor:k(ispeed/idur)*idur
  krow = kplayhead / idt
  ; each row has the format frametime, freq0, amp0, bandwidth0, freq1, amp1, bandwidth1, ...
  kF[] getrowlin krow, ifn, inumcols, iskip, 1, 0, 3
  kA[] getrowlin krow, ifn, inumcols, iskip, 2, 0, 3
  kB[] getrowlin krow, ifn, inumcols, iskip, 3, 0, 3
 
  iflags = $flag
  aout beadsynt kF, kA, kB, -1, iflags, ifreqscale
  
  if(kt > idur) then
    event "e", 0, 0, 0
  endif
  aenv cosseg 0, 0.02, igain, idur-0.02-0.1, igain, 0.1, 0
  aout *= aenv
  outs aout, aout
  
endin

schedule 1, 0, -1

</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
    """)
    csdstr = template.safe_substitute(out=out, 
                                      mtxfile=mtxfile, 
                                      rtbackend=rtbackend,
                                      nchnls=nchnls,
                                      sr=sr,
                                      ksmps=ksmps,
                                      flag=flag,
                                      speed=str(speed), 
                                      freqscale=str(freqscale), 
                                      gain=str(gain))
    csd = tempfile.mktemp(suffix=".csd", prefix="loristrck-")
    with open(csd, "w") as f:
        f.write(csdstr)
    cmd = [csoundbin, '-d', '-m0', csd]
    if blocking:
        subprocess.call(cmd)
    else:
        return subprocess.Popen(cmd)
