import loristrck as lt
import sndfileio
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outfile', default='test1.wav')
parser.add_argument('--plot', action='store_true')
args = parser.parse_args()

sndfile = "sound/musicbox-tchaikovsky-44k1-1.flac"

samples, sr = sndfileio.sndread(sndfile)
samples0 = sndfileio.util.getchannel(samples, 0)
partials = lt.analyze(samples0, sr, resolution=80)
selection = lt.util.partials_between(partials, 2, 4)
selection = lt.util.partials_stretch(selection, 5)
faded = [lt.util.partial_fade(p, 0.5, 0.5) for p in selection]

if args.plot:
    lt.util.plot_partials(selection)

print("Synthesizing faded version")
synthesized = lt.synthesize(faded, sr)
sndfileio.sndwrite("sound/faded.mp3", synthesized, sr=sr)
print(f"Found {len(partials)} partials, reduced to {len(selection)}")

