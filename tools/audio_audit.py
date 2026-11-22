#!/usr/bin/env python3
"""Gate A / A3: waveform audit of every shipped WAV (the crackle hunt).

Facts, per file: format, rate, channels, duration, peak dBFS, RMS dBFS,
DC offset, clipped sample count, loop-seam discontinuity (first vs last
N samples), and silence. Anything harsh (square/saw content shows as
very low zero-crossing spacing with high RMS) is flagged.
Usage: python3 -I tools/audio_audit.py [dir]
"""
import pathlib
import struct
import sys
import wave

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                    else "/home/z/my-project/assets/audio")


def db(x: float) -> float:
    import math
    return 20.0 * math.log10(x) if x > 0 else -120.0


def main() -> None:
    print(f"{'file':26} {'rate':>6} {'ch':>3} {'len_s':>6} "
          f"{'peak':>7} {'rms':>7} {'dc':>7} {'clip':>5} {'seam':>7}  flag")
    for f in sorted(ROOT.glob("*.wav")):
        try:
            w = wave.open(str(f), "rb")
        except Exception as e:  # noqa: BLE001
            print(f"{f.name:26} NOT-A-WAV ({e})")
            continue
        nch, sw, rate, nfr = w.getnchannels(), w.getsampwidth(), \
            w.getframerate(), w.getnframes()
        raw = w.readframes(nfr)
        w.close()
        if sw != 2:
            print(f"{f.name:26} {rate} {nch}ch {sw * 8}bit - SKIP (not 16-bit)")
            continue
        samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
        peak = max(abs(s) for s in samples) / 32768.0 if samples else 0.0
        rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5 / 32768.0
        dc = sum(samples) / max(1, len(samples)) / 32768.0
        clipped = sum(1 for s in samples if abs(s) >= 32000)
        # loop seam: the sample step AT the wrap, compared to the file's
        # typical adjacent-sample movement (a click is a step many times
        # larger than normal signal movement)
        wrap = abs(samples[0] - samples[-1])
        idxs = list(range(0, len(samples) - 1, 97))
        typical = sum(abs(samples[i + 1] - samples[i]) for i in idxs) \
            / max(1, len(idxs))
        seam = wrap / max(typical, 1.0)
        dur = nfr / rate
        flags = []
        if peak > 0.98:
            flags.append("CLIPPING")
        if abs(dc) > 0.02:
            flags.append("DC")
        if clipped > 0:
            flags.append(f"clip={clipped}")
        if seam > 6.0 and dur >= 1.0:  # one-shots never loop
            flags.append("LOOP-SEAM")
        if rms > 0.25:
            flags.append("LOUD/HARSH")
        if rms < 0.005:
            flags.append("SILENT")
        if rate < 22050:
            flags.append("low-rate")
        print(f"{f.name:26} {rate:>6} {nch:>3} {dur:>6.1f} "
              f"{db(peak):>6.1f} "
              f"{db(rms):>6.1f} "
              f"{dc:>7.3f} {clipped:>5} {seam:>7.3f}  {' '.join(flags) or 'ok'}")


if __name__ == "__main__":
    main()
