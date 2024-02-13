import loristrck as lt
import sndfileio
import os
import argarse

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outfile', default='stretched.mp3')
parser.add_argument('--plot', action='store_true')
args = parser.parse_args()


sndfile = "sound/musicbox-tchaikovsky-44k1-1.flac"
outdir = 'soundout'
minpartialdur = 0.008

os.makedirs(outdir, exist_ok=)


samples, sr = sndfileio.sndread(sndfile)
samples0 = sndfileio.util.getchannel(samples, 0)
partials = lt.analyze(samples0, sr, resolution=80)
selection = lt.util.partials_between(partials, 0, 2)
# Remove very short partials
selection = [p for p in selection if p[-1, 0] - p[0, 0] > minpartialdur]
selection = [lt.util.partial_crop(p, 0, 2) for p in selection]

if args.plot:
    lt.util.plot_partials(selection)

stretched = lt.util.partials_stretch(selection, 20)
print("Synthesizing stretched version")
synthesized = lt.synthesize(stretched, sr)
stretchedfile = os.path.join(outdir, outfile)
sndfileio.sndwrite(stretchedfile, synthesized, sr=sr)
print(f"Found {len(partials)} partials, reduced to {len(selection)}")

