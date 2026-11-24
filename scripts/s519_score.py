#!/usr/bin/env python3
"""S5.19 THE SCORE: a composed noir cue for the menu - a walking
upright bass (Karplus-Strong plucks), brushed drums (filtered
noise swells + soft ride ticks), sparse piano stabs (decaying
harmonic stacks), vinyl crackle. D minor, ~92 BPM, 16 bars that
loop cleanly. Written to assets/audio/music_noir.wav."""
import numpy as np
import wave
import struct

SR = 22050
BPM = 92.0
BEAT = 60.0 / BPM
BARS = 16
N = int(SR * BEAT * 4 * BARS)
out = np.zeros(N)

rng = np.random.default_rng(1949)


def ks_pluck(freq, dur, decay=0.996, bright=0.5):
    """Karplus-Strong: a plucked string with real overtones."""
    n = int(SR / freq)
    buf = rng.uniform(-1, 1, n)
    n_s = int(SR * dur)
    out_s = np.empty(n_s)
    for i in range(n_s):
        v = buf[i % n]
        nxt = buf[(i + 1) % n]
        buf[i % n] = decay * 0.5 * (v + nxt)
        out_s[i] = v
    # soften the attack a hair (felt on the strings)
    a = min(220, int(0.005 * SR))
    if a > 0:
        out_s[:a] *= np.linspace(0.2, 1.0, a)
    return out_s


def add(sig, at_s, gain=1.0):
    i0 = int(at_s * SR)
    i1 = min(N, i0 + len(sig))
    if i0 >= N:
        return
    out[i0:i1] += sig[: i1 - i0] * gain


def dmin_notes(deg):
    """D minor scale degrees -> freq (A=220)."""
    semis = [0, 2, 3, 5, 7, 8, 10]
    return 220.0 * 2 ** (semis[deg % 7] / 12.0 + (deg // 7) - 1)


# --- THE WALKING BASS: roots, fifths, chromatic approaches
# D-7 | G-7 | D-7 | A7b13 | repeated with variations
progression = [
    ("D2", "A2", "F2", "A2"),   # D-7 walk
    ("G2", "D3", "Bb2", "D3"),  # G-7
    ("D2", "A2", "F2", "C3"),   # D-7
    ("A2", "Eb3", "C#3", "E3"), # A7b13 pull
]
note_semi = {"D2": -31, "A2": -24, "F2": -28, "G2": -29, "Bb2": -26,
             "C3": -21, "Eb3": -20, "C#3": -22, "E3": -19, "D3": -19}
bar = 0
while bar < BARS:
    walk = progression[(bar // 4) % 1 + (bar % 4)]
    for beat_i, name in enumerate(walk):
        freq = 220.0 * 2 ** (note_semi[name] / 12.0)
        t0 = (bar * 4 + beat_i) * BEAT
        pl = ks_pluck(freq, 1.4, 0.9965)
        # the pocket: swing the 2nd/4th a touch late
        swing = 0.03 * (beat_i % 2)
        add(pl, t0 + swing, 0.5)
        # an occasional ghost octave at the bar's end
        if beat_i == 3 and bar % 2 == 1:
            add(ks_pluck(freq * 2, 0.8, 0.996), t0 + 0.5, 0.2)
    bar += 1

# --- THE BRUSHES: a soft swell per beat, ride tick on 2/4
def brush_swell(dur=0.5):
    n_s = int(SR * dur)
    env = np.hanning(n_s) ** 2
    noise = rng.normal(0, 1, n_s)
    # band-limit to the wire-brush hiss
    kern = np.ones(24) / 24
    return np.convolve(noise, kern, "same") * env * 0.7


def ride_tick(dur=0.06):
    n_s = int(SR * dur)
    t = np.arange(n_s) / SR
    env = np.exp(-t * 60)
    v = np.sin(2 * np.pi * 3200 * t) + 0.4 * np.sin(2 * np.pi * 5100 * t)
    return v * env


for b in range(BARS * 4):
    t0 = b * BEAT
    add(brush_swell(), t0, 0.06 if b % 2 else 0.09)
    if b % 2 == 1:
        add(ride_tick(), t0 + BEAT * 0.62, 0.05)

# --- THE PIANO: sparse minor stabs, chords on the 1, off-beat
# single notes answer the bass in bars 5-8 / 13-16
def piano(freqs, dur=1.8, gain=1.0):
    n_s = int(SR * dur)
    t = np.arange(n_s) / SR
    v = np.zeros(n_s)
    for f in freqs:
        for h, hg in [(1, 1.0), (2, 0.45), (3, 0.18), (4, 0.08)]:
            v += hg * np.sin(2 * np.pi * f * h * t) \
                    * np.exp(-t * (2.1 + h * 0.9))
    return v * gain


for bar_x in range(0, BARS, 2):
    root = progression[(bar_x % 4)]
    f_root = 220.0 * 2 ** (note_semi[root[0]] / 12.0) * 2
    chord = [f_root, f_root * 2 ** (3 / 12), f_root * 2 ** (7 / 12)]
    add(piano(chord, 2.2, 0.16), bar_x * 4 * BEAT)
    if bar_x % 4 == 2:
        add(piano([f_root * 2 ** (10 / 12)], 1.2, 0.1),
                (bar_x * 4 + 2.5) * BEAT)

# --- THE VINYL: sparse dust crackle under everything
n_ticks = int(N / SR * 9)
for _ in range(n_ticks):
    i0 = rng.integers(0, N - 40)
    amp = rng.uniform(0.02, 0.1) * (2 * rng.integers(0, 2) - 1)
    out[i0:i0 + 30] += amp * np.hanning(30)

# --- THE MASTER: gentle bus comp + the loop fade
out = np.tanh(out * 1.6) * 0.85
# seamless loop: 1.2 s crossfade tail into the head
xf = int(SR * 1.2)
tail = out[-xf:].copy()
head = out[:xf].copy()
out[:xf] = head * np.linspace(0, 1, xf) + tail * np.linspace(1, 0, xf)
out = out[:-xf]

# normalize to -1 dB
peak = np.max(np.abs(out))
out = out / peak * 0.89
pcm = (out * 32767).astype(np.int16)
with wave.open("assets/audio/music_noir.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("score written: %d s, %d samples, peak %.2f"
      % (len(out) // SR, len(out), peak))
