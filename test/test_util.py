"""Pure-python regression tests for loristrck.util.

These tests stub out loristrck._core when the compiled extension is not
available, so they run on any platform without fftw/Loris.
"""
import sys
import types

import numpy as np
import pytest


def _install_core_stub():
    if "loristrck._core" in sys.modules:
        return
    try:
        import importlib
        importlib.import_module("loristrck._core")
        return
    except Exception:
        pass
    fake = types.ModuleType("loristrck._core")

    def meancol(X, col):
        return float(np.asarray(X)[:, col].mean())

    def meancolw(X, col, colw):
        X = np.asarray(X)
        x = X[:, col]
        w = X[:, colw]
        return float((x * w).sum() / w.sum())

    def synthesize(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def _write_sdif(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def analyze(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def read_sdif(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def read_aiff(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def estimatef0(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def kaiserWindowLength(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    def newPartialList(*args, **kwargs):
        raise RuntimeError("_core extension not built")

    class PartialListW:  # minimal stub for type imports
        pass

    fake.meancol = meancol
    fake.meancolw = meancolw
    fake.synthesize = synthesize
    fake._write_sdif = _write_sdif
    fake.analyze = analyze
    fake.read_sdif = read_sdif
    fake.read_aiff = read_aiff
    fake.estimatef0 = estimatef0
    fake.kaiserWindowLength = kaiserWindowLength
    fake.newPartialList = newPartialList
    fake.PartialListW = PartialListW
    sys.modules["loristrck._core"] = fake


_install_core_stub()

from loristrck import util  # noqa: E402


def _partial(t0=0.0, t1=1.0, n=11, freq=440.0, amp=1.0):
    t = np.linspace(t0, t1, n)
    p = np.zeros((n, 5))
    p[:, 0] = t
    p[:, 1] = freq
    p[:, 2] = amp
    p[:, 3] = 0.0
    p[:, 4] = 0.0
    return p


def test_partial_sample_regularly_uses_dt():
    p = _partial(0.0, 1.0, n=101)
    out = util.partial_sample_regularly(p, dt=0.1)
    times = out[:, 0]
    assert len(times) >= 9
    diffs = np.diff(times)
    assert np.allclose(diffs, 0.1, atol=1e-6)


def test_partials_transpose_non_inplace_uses_ratio():
    p = _partial(freq=100.0)
    out = util.partials_transpose([p], 12.0, inplace=False)
    assert out[0][:, 1].mean() == pytest.approx(200.0)
    # input untouched
    assert p[:, 1].mean() == pytest.approx(100.0)


def test_partials_transpose_inplace():
    p = _partial(freq=100.0)
    util.partials_transpose([p], 12.0, inplace=True)
    assert p[:, 1].mean() == pytest.approx(200.0)


def test_limit_matrix_zeroes_softest_per_row():
    m = np.array([[1.0, 5.0, 3.0], [9.0, 2.0, 7.0]])
    util._limit_matrix(m, 1)
    # only the loudest per row survives
    assert sorted(m[0].tolist()) == pytest.approx([0.0, 0.0, 5.0])
    assert sorted(m[1].tolist()) == pytest.approx([0.0, 0.0, 9.0])


def test_limit_matrix_interleaved():
    m = np.zeros((1, 1 + 3 * 3))
    m[0, 0] = 0.0
    m[0, 1::3] = [100.0, 200.0, 300.0]  # freqs
    m[0, 2::3] = [1.0, 5.0, 3.0]  # amps
    util._limit_matrix_interleaved(m, 1)
    amps = m[0, 2::3]
    assert sorted(amps.tolist()) == pytest.approx([0.0, 0.0, 5.0])


def test_sndwrite_rejects_bad_encoding(tmp_path):
    samples = np.zeros(16)
    with pytest.raises(ValueError):
        util.sndwrite(samples, 44100, str(tmp_path / "x.wav"), encoding="pcm99")


def test_sndwrite_roundtrip_wav(tmp_path):
    soundfile = pytest.importorskip("soundfile")
    sr = 44100
    samples = (np.arange(64, dtype=float) / 64).astype(float)
    path = str(tmp_path / "t.wav")
    util.sndwrite(samples, sr, path, encoding="float32")
    back, sr2 = util.sndread(path)
    assert sr2 == sr
    assert np.allclose(back, samples, atol=1e-6)


def test_partial_crop_no_interior_breakpoints():
    # partial has bps only at 0 and 10; crop 4..6 must interpolate endpoints
    p = np.array([[0.0, 440, 1, 0, 0], [10.0, 440, 1, 0, 0]], dtype=float)
    out = util.partial_crop(p, 4.0, 6.0)
    assert out.shape == (2, 5)
    assert out[0, 0] == pytest.approx(4.0)
    assert out[-1, 0] == pytest.approx(6.0)


def test_partial_crop_disjoint_raises():
    p = _partial(0.0, 1.0)
    with pytest.raises(ValueError):
        util.partial_crop(p, 5.0, 6.0)


def test_partials_at_ignores_out_of_range():
    p = _partial(0.0, 1.0, freq=440.0)
    # t=5 is outside partial; partial_at returns None and must be skipped
    bps = util.partials_at([p], t=5.0)
    assert bps == []


def test_partials_at_basic():
    p = _partial(0.0, 1.0, freq=440.0, amp=1.0)
    bps = util.partials_at([p], t=0.5)
    assert len(bps) == 1
    assert bps[0][0] == pytest.approx(440.0, rel=0.05)


def test_partial_index_clamps():
    partials = [_partial(i, i + 0.5, freq=200 + i * 10) for i in range(5)]
    idx = util.PartialIndex(partials, dt=0.5)
    # queries outside indexed range must not IndexError
    assert idx.partials_between(-10.0, -9.0) == []
    out = idx.partials_between(0.0, 10.0)
    assert len(out) > 0
    with pytest.raises(ValueError):
        idx.partials_between(2.0, 1.0)


def test_db2amp():
    assert util.db2amp(0.0) == pytest.approx(1.0)
    assert util.db2amp(-6.0) == pytest.approx(0.501, rel=1e-2)
