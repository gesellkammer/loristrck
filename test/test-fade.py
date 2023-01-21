import loristrck as lt
import sndfileio
sndfile = "sound/musicbox-tchaikovsky-44k1-1.flac"

samples, sr = sndfileio.sndread(sndfile)
samples0 = sndfileio.util.getchannel(samples, 0)
partials = lt.analyze(samples0, sr, resolution=80)
selection = lt.util.partials_between(partials, 2, 4)
selection = lt.util.partials_stretch(selection, 5)
faded = [lt.util.partial_fade(p, 0.5, 0.5) for p in selection]
lt.util.plot_partials(selection)
print("Synthesizing faded version")
synthesized = lt.synthesize(faded, sr)
sndfileio.sndwrite("sound/faded.mp3", synthesized, sr=sr)
print(f"Found {len(partials)} partials, reduced to {len(selection)}")
import matplotlib.pyplot as plt
plt.show()

