import loristrck as lt
import sndfileio
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outfile', default='test1.wav')
args = parser.parse_args()

sndfile = "sound/musicbox-tchaikovsky-44k1-1.flac"
minpartialdur = 0.008

samples, sr = sndfileio.sndread(sndfile)
samples0 = sndfileio.util.getchannel(samples, 0)
partials = lt.analyze(samples0, sr, resolution=80)
selection = lt.util.partials_between(partials, 0, 2)
# Remove very short partials
selection = [p for p in selection if p[-1, 0] - p[0, 0] > minpartialdur]
selection = [lt.util.partial_crop(p, 0, 2) for p in selection]
stretched = lt.util.partials_stretch(selection, 20)
print(f"Synthesizing stretched version: '{args.outfile}'")
synthesized = lt.synthesize(stretched, sr)
sndfileio.sndwrite(args.outfile, synthesized, sr=sr)
print(f"Found {len(partials)} partials, reduced to {len(selection)}")

