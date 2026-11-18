#!/usr/bin/env python3
"""Series 2: synthesize ambience loops, puddle splashes (Phase 1) and the
placeholder music stems (Phase 2) as small mono 22050 Hz WAVs. Made entirely
in code by this project - no third-party audio. Output: quarantine folder."""
import math, random, struct, wave, pathlib

SR = 22050
OUT = pathlib.Path("/home/z/my-project/downloads_check/audio")
OUT.mkdir(parents=True, exist_ok=True)
random.seed(1812)


def write_wav(name: str, samples: list[float]) -> None:
    # normalize to -3 dBFS headroom, clip, 16-bit
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.7 / peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
            for s in samples))
    print("wrote", name, "%.1fs" % (len(samples) / SR))


def lp(state: float, x: float, a: float) -> float:
    # one-pole lowpass; a = coefficient
    return state + (x - state) * a


def silence(sec: float) -> list[float]:
    return [0.0] * int(SR * sec)


# --- Phase 1: ambience loops -------------------------------------------------


def rain_asphalt() -> None:
    n = int(SR * 6.0)
    out, st = [], 0.0
    for _ in range(n):
        st = lp(st, random.uniform(-1, 1), 0.22)  # gentle hiss
        out.append(st * 0.5)
    # droplet ticks, wrapped so the loop stays seamless
    for _ in range(90):
        p = random.randrange(n)
        for k in range(40):
            out[(p + k) % n] += (1.0 - k / 40) * random.uniform(0.1, 0.3)
    write_wav("rain_asphalt.wav", out)


def rain_metal() -> None:
    n = int(SR * 6.0)
    out, st = [], 0.0
    for _ in range(n):
        st = lp(st, random.uniform(-1, 1), 0.5)
        out.append(st * 0.28)
    for _ in range(40):  # metallic pings
        p = random.randrange(n)
        f = random.uniform(1800, 3600)
        for k in range(int(SR * 0.09)):
            env = math.exp(-k / (SR * 0.014))
            out[(p + k) % n] += math.sin(2 * math.pi * f * k / SR) * env * 0.35
    write_wav("rain_metal.wav", out)


def traffic() -> None:
    n = int(SR * 8.0)
    out, st, st2 = [], 0.0, 0.0
    for _ in range(n):
        st = lp(st, random.uniform(-1, 1), 0.045)   # deep rumble
        st2 = lp(st2, random.uniform(-1, 1), 0.12)  # mid wash
        out.append(st * 0.9 + st2 * 0.25)
    for _ in range(4):  # passing car swell
        c = random.randrange(n)
        length = int(SR * 2.2)
        for k in range(length):
            env = math.exp(-((k - length / 2) / (length / 4)) ** 2)
            out[(c + k) % n] += st2 * env * 0.8 if (c + k) % SR < SR else 0
            out[(c + k) % n] += 0.0
    # a distant horn, twice
    for c in [int(n * 0.31), int(n * 0.72)]:
        for k in range(int(SR * 0.5)):
            t = k / SR
            env = min(1, t * 30) * math.exp(-t * 3.5)
            v = (math.sin(2 * math.pi * 311 * t) + math.sin(2 * math.pi * 370 * t)) * 0.06 * env
            out[(c + k) % n] += v
    write_wav("traffic.wav", out)


def hum() -> None:
    n = int(SR * 4.0)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(2 * math.pi * 100 * t) * 0.5
             + math.sin(2 * math.pi * 120 * t + 0.3) * 0.35
             + math.sin(2 * math.pi * 300 * t) * 0.06
             + math.sin(2 * math.pi * 99.1 * t) * 0.12)  # slow beat
        out.append(v)
    write_wav("hum.wav", out)


def siren() -> None:
    n = int(SR * 8.0)
    out, dl = [], [0.0] * int(SR * 0.18)
    for i in range(n):
        t = i / SR
        f = 700 + 130 * math.sin(2 * math.pi * 0.22 * t)
        v = math.sin(2 * math.pi * f * t) * 0.16
        v = lp(dl[-1] if False else v, v, 1) if False else v
        v = v + dl[i % len(dl)] * 0.35  # cheap echo
        dl[i % len(dl)] = v
        out.append(v)
    write_wav("siren.wav", out)


def splash(idx: int) -> None:
    n = int(SR * 0.3)
    out, st = [], 0.0
    f0 = random.uniform(700, 950)
    for k in range(n):
        t = k / SR
        hp = random.uniform(-1, 1) - st  # crudely highpassed noise
        st = lp(st, random.uniform(-1, 1), min(0.95, t * 3 + 0.05))
        env = math.exp(-t * 18)
        plip = math.sin(2 * math.pi * (f0 - 420 * t) * t) * math.exp(-t * 22) * 0.8
        out.append(hp * env * 0.5 + plip)
    write_wav("splash_%d.wav" % idx, out)


# --- Phase 2: placeholder music stems (88 BPM, D minor) -----------------------

BPM = 88.0
BEAT = 60.0 / BPM


def note(freq: float, dur: float, vol: float, decay: float) -> list[float]:
    n = int(SR * dur)
    out = []
    for k in range(n):
        t = k / SR
        v = (math.sin(2 * math.pi * freq * t)
             + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
             + 0.15 * math.sin(2 * math.pi * freq * 3 * t))
        out.append(v * vol * math.exp(-t * decay))
    return out


def mix(dst: list[float], src: list[float], at_sec: float) -> None:
    p = int(at_sec * SR)
    for k, v in enumerate(src):
        if p + k < len(dst):
            dst[p + k] += v


def pad_tone(freq: float, dur: float, vol: float) -> list[float]:
    n = int(SR * dur)
    out, lps = [], 0.0
    for k in range(n):
        t = k / SR
        # detuned saw-ish stack, soft opening filter
        v = (math.sin(2 * math.pi * freq * t * 1.003)
             + math.sin(2 * math.pi * freq * t * 0.997)
             + 0.5 * math.sin(2 * math.pi * freq * 2 * t)
             + 0.25 * math.sin(2 * math.pi * freq * 3 * t))
        a = 0.08 + 0.16 * (0.5 - 0.5 * math.cos(2 * math.pi * t / dur))
        lps = lp(lps, v, a)
        out.append(lps * vol)
    return out


def music_bed() -> None:
    bars, sec = 4, BEAT * 16
    out = silence(sec)
    for f in [73.42, 110.0, 146.83, 174.61]:  # D2 A2 D3 F3
        mix(out, pad_tone(f, sec, 0.16), 0.0)
    # bar 3: Bb colour
    for f in [116.54, 174.61, 233.08]:
        mix(out, pad_tone(f, BEAT * 4, 0.10), BEAT * 8)
    write_wav("music_bed.wav", out)


def music_tension() -> None:
    sec = BEAT * 8
    out = silence(sec)
    for b in [0.0, 1.5, 3.0, 4.0, 5.5, 7.0]:  # sparse dotted pulses
        mix(out, note(146.83, 0.5, 0.30, 6.0), b)
        mix(out, note(73.42, 0.4, 0.35, 8.0), b)
    write_wav("music_tension.wav", out)


def music_combat() -> None:
    sec = BEAT * 8
    out = silence(sec)
    bass = [73.42, 73.42, 87.31, 98.0]  # D2 D2 F2 G2 per bar
    for bar in range(4):
        for e in range(8):  # 8th-note bass
            t = (bar * 8 + e) * BEAT / 2
            mix(out, note(bass[bar], 0.16, 0.5, 14.0), t)
        for e in range(8):  # hats
            t = (bar * 8 + e) * BEAT / 2 + BEAT / 4
            mix(out, note(6000 + random.uniform(-800, 800), 0.05, 0.06, 60.0), t)
        for sb in [1, 3]:  # snare on 2 and 4
            t = (bar * 4 + sb) * BEAT
            n = int(SR * 0.12)
            for k in range(n):
                pass
            mix(out, [random.uniform(-1, 1) * math.exp(-k / (SR * 0.02)) * 0.3
                      for k in range(int(SR * 0.12))], t)
    write_wav("music_combat.wav", out)


def music_heartbeat() -> None:
    # one pair: LUB .. DUB, ~0.8 s; runtime scales speed with heat
    out = silence(0.85)
    for at, vol, dec in [(0.0, 0.9, 16.0), (0.22, 0.6, 20.0)]:
        n = int(SR * 0.16)
        thump = [math.sin(2 * math.pi * 52 * k / SR) * math.exp(-k / (SR / dec)) * vol
                 for k in range(n)]
        mix(out, thump, at)
    write_wav("music_heartbeat.wav", out)


def music_resolve() -> None:
    sec = 6.0
    out = silence(sec)
    for f, v in [(146.83, 0.3), (174.61, 0.25), (220.0, 0.2), (329.63, 0.12)]:  # D3 F3 A3 E4
        mix(out, note(f, sec, v, 1.1), 0.0)
    write_wav("music_resolve.wav", out)


if __name__ == "__main__":
    rain_asphalt()
    rain_metal()
    traffic()
    hum()
    siren()
    for i in range(3):
        splash(i)
    music_bed()
    music_tension()
    music_combat()
    music_heartbeat()
    music_resolve()
