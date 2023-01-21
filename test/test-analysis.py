import loristrck as lt
import sndfileio
sndfile = "sound/musicbox-tchaikovsky-44k1-1.flac"
minpartialdur = 0.008

samples, sr = sndfileio.sndread(sndfile)
samples0 = sndfileio.util.getchannel(samples, 0)
partials = lt.analyze(samples0, sr, resolution=80)
selection = lt.util.partials_between(partials, 0, 2)
# Remove very short partials
selection = [p for p in selection if p[-1, 0] - p[0, 0] > minpartialdur]
selection = [lt.util.partial_crop(p, 0, 2) for p in selection]
lt.util.plot_partials(selection)
stretched = lt.util.partials_stretch(selection, 20)
print("Synthesizing stretched version")
synthesized = lt.synthesize(stretched, sr)
sndfileio.sndwrite("sound/stretched.mp3", synthesized, sr=sr)
print(f"Found {len(partials)} partials, reduced to {len(selection)}")
import matplotlib.pyplot as plt
plt.show()

