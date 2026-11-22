#!/usr/bin/env python3
"""Gate A / A3: re-master every project-owned audio loop.

The device evidence: 'one loud, harsh, crackling noise on loop'. The
audit (tools/audio_audit.py) found the cause in the shipped files:
loop-seam discontinuities (a click every loop), unfiltered noise beds
(rain = raw white noise, hot), DC on the traffic loop, and 22050 Hz
thinness on a phone speaker. This tool re-renders the 13 project-owned
WAVs (the Kenney CC0 SFX files are professional masters and are NOT
touched) with:
  - 44100 Hz, 16-bit mono
  - seamless loops (the tail crossfades into the head, 120 ms)
  - band-limited beds (one-pole low-pass; rain is shaped pink-ish
    noise, not white), soft percussive layers instead of raw saws
  - mastering: DC removed, peak normalised to -3 dBFS, bed RMS around
    -24..-20 dB (music) and -28..-24 (ambience) - quiet by default
"""
import math
import pathlib
import random
import struct
import wave

OUT = pathlib.Path("/home/z/my-project/assets/audio")
RATE = 44100
PEAK = 10.0 ** (-3.0 / 20.0)  # -3 dBFS
XFADE = 0.12  # seconds


class LP:
    """One-pole low-pass (the softening that kills the harshness)."""

    def __init__(self, cutoff: float) -> None:
        self.a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        self.y = 0.0

    def __call__(self, x: float) -> float:
        self.y += self.a * (x - self.y)
        return self.y


def save(name: str, gen, dur: float, rms_db: float = -20.0,
        crossfade: bool = False) -> None:
    n = int(RATE * dur)
    raw = [max(-1.0, min(1.0, gen(i / RATE))) for i in range(n)]
    # DC removal
    mean = sum(raw) / max(1, n)
    raw = [s - mean for s in raw]
    # loop crossfade for NOISE beds only: blend the tail into the head
    # so the wrap is continuous. Tonal loops are periodic by construction
    # (snapped frequencies) and a crossfade would only mix a phase-shifted
    # copy into their tail.
    if crossfade:
        k = min(int(RATE * XFADE), n // 4)
        for i in range(k):
            w = i / k
            raw[n - k + i] = raw[n - k + i] * (1.0 - w * 0.5) + raw[i] * (w * 0.5)
    # master to the per-file RMS target, capped at the peak ceiling
    rms = (sum(s * s for s in raw) / max(1, n)) ** 0.5
    peak = max(abs(s) for s in raw) or 1.0
    g_rms = (10.0 ** (rms_db / 20.0)) / max(rms, 1e-9)
    g_peak = PEAK / peak
    g = min(g_rms, g_peak)
    data = struct.pack("<%dh" % n, *(int(s * g * 32767.0) for s in raw))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    got = 20 * math.log10((sum(s * s for s in raw) / n) ** 0.5 * g + 1e-9)
    print(f"mastered {name:24} {dur:5.1f}s rms {got:6.1f} dBFS (target {rms_db})")


def snap(f: float, dur: float) -> float:
    """Snap a frequency to an integer multiple of 1/dur so the tone is
    PERIODIC over the loop: the wrap is click-free by construction."""
    return round(f * dur) / dur


def main() -> None:
    rng = random.Random(11)

    # --- music ---------------------------------------------------------------
    # bed: a warm noir pad - A minor (A2 E3 A3 C4 E4) sines, slow
    # tremolo; frequencies snapped so the 12 s loop wraps silently
    bed_dur = 12.0
    bed_chord = [snap(f, bed_dur) for f in (110.0, 164.8, 220.0, 261.6, 329.6)]
    bed_trem = snap(0.12, bed_dur)
    def bed(t: float) -> float:
        s = sum(math.sin(2 * math.pi * f * t + 0.3 * i)
                for i, f in enumerate(bed_chord))
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * bed_trem * t)
        return s / len(bed_chord) * 0.8 * trem

    save("music_bed.wav", bed, bed_dur, rms_db=-20.0)

    # tension: a filtered pulse bass breathing, plus a sparse soft tick
    ten_dur = 12.0
    lp_t = LP(420.0)
    ten_pulse = snap(110.0, ten_dur)
    ten_breath = snap(0.25, ten_dur)
    def tension(t: float) -> float:
        # a soft TRIANGLE (periodic, no filter state at the wrap)
        ph = (ten_pulse * t) % 1.0
        pulse = 2.0 * abs(2.0 * ph - 1.0) - 1.0
        v = pulse * (0.55 + 0.45 * math.sin(2 * math.pi * ten_breath * t))
        if ((t + 0.06) % 1.5) < 0.012:  # off the wrap
            v += 0.25 * math.sin(2 * math.pi * 1200.0 * t)
        return v * 0.7

    save("music_tension.wav", tension, ten_dur, rms_db=-22.0)

    # combat: soft percussive loop (thump + shaped noise hat), 2 bars
    lp_c = LP(900.0)
    def combat(t: float) -> float:
        b = t % 1.3636  # 88 BPM
        v = 0.0
        for off in (0.0, 0.68):  # the thumps
            ph = (b - off) % 1.3636
            if 0.0 <= ph < 0.22:
                v += math.sin(2 * math.pi * 62.0 * ph) * math.exp(-ph * 26.0)
        if 0.34 < b < 0.40 or 1.02 < b < 1.08:  # the hats
            v += lp_c(rng.random() * 2 - 1) * 0.35
        return v * 0.9

    save("music_combat.wav", combat, 5.4544, rms_db=-20.0)

    # heartbeat: two soft thumps, gentle
    def heartbeat(t: float) -> float:
        ph = t % 1.0
        v = math.sin(2 * math.pi * 55.0 * ph) * math.exp(-ph * 20.0)
        if ph > 0.32:
            p2 = ph - 0.32
            v += 0.6 * math.sin(2 * math.pi * 50.0 * p2) * math.exp(-p2 * 22.0)
        return v * 0.8

    save("music_heartbeat.wav", heartbeat, 1.0, rms_db=-22.0)

    # resolve: a calm descending phrase, sine, slow, periodic wrap
    res_dur = 6.0
    notes = [snap(f, res_dur) for f in (523.3, 440.0, 349.2, 293.7, 220.0)]
    def resolve(t: float) -> float:
        idx = min(int(t / 1.2), len(notes) - 1)
        lt = t - idx * 1.2
        f = notes[idx]
        env = min(1.0, lt * 4.0) * math.exp(-lt * 1.1)
        return (math.sin(2 * math.pi * f * t)
                + 0.4 * math.sin(2 * math.pi * f * 2 * t)) * env * 0.5

    save("music_resolve.wav", resolve, res_dur, rms_db=-18.0)

    # --- ambience (noise beds: the crossfade handles the wrap) ---------------
    # rain on asphalt: pink-ish filtered noise + sparse soft droplets
    lp_r = LP(1100.0)
    def rain(t: float) -> float:
        v = lp_r((rng.random() * 2 - 1) * 0.8)
        if rng.random() < 0.0007:
            v += 0.3 * math.sin(2 * math.pi * rng.uniform(500, 1500) * t) \
                * math.exp(-rng.random() * 30)
        return v

    save("rain_asphalt.wav", rain, 8.0, rms_db=-26.0, crossfade=True)

    # rain on metal: brighter, sparser pings
    lp_m = LP(2400.0)
    def rain_metal(t: float) -> float:
        v = lp_m((rng.random() * 2 - 1) * 0.35)
        if rng.random() < 0.001:
            f = rng.uniform(1200, 2600)
            v += 0.5 * math.sin(2 * math.pi * f * t) * math.exp(-t % 0.05 * 90)
        return v

    save("rain_metal.wav", rain_metal, 8.0, rms_db=-30.0, crossfade=True)

    # traffic: a low rumble with slow swells
    lp_lo = LP(180.0)
    def traffic(t: float) -> float:
        swell = 0.5 + 0.5 * math.sin(2 * math.pi * 0.07 * t) \
            * math.sin(2 * math.pi * 0.031 * t + 1.0)
        return lp_lo(rng.random() * 2 - 1) * (0.5 + swell)

    save("traffic.wav", traffic, 9.0, rms_db=-26.0, crossfade=True)

    # hum: a quiet 120 Hz with soft harmonics, perfectly steady
    hum_dur = 4.0
    hum_h = [snap(f, hum_dur) for f in (120.0, 240.0, 360.0)]
    def hum(t: float) -> float:
        return (math.sin(2 * math.pi * hum_h[0] * t) * 0.6
                + math.sin(2 * math.pi * hum_h[1] * t) * 0.25
                + math.sin(2 * math.pi * hum_h[2] * t) * 0.08) * 0.5

    save("hum.wav", hum, hum_dur, rms_db=-30.0)

    # siren: a distant wail, low-passed and quiet
    sir_dur = 8.0
    sir_w = snap(0.14, sir_dur)
    def siren(t: float) -> float:
        f = 700.0 + 160.0 * math.sin(2 * math.pi * sir_w * t)
        v = math.sin(2 * math.pi * f * t) * (0.4 + 0.3 * math.sin(2 * math.pi * sir_w * t))
        return v * 0.45

    save("siren.wav", siren, sir_dur, rms_db=-28.0)

    # splashes: short filtered noise bursts with a fast decay
    for i, seed in enumerate((3, 7, 12)):
        r2 = random.Random(seed)
        lp_s = LP(1600.0 + 400 * i)
        def splash(t: float, _lp=lp_s, _r=r2) -> float:
            env = math.exp(-t * 46.0)
            return _lp((_r.random() * 2 - 1)) * env * 0.9

        save(f"splash_{i}.wav", splash, 0.3, rms_db=-20.0)


if __name__ == "__main__":
    main()
