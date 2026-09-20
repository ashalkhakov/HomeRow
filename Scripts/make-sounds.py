#!/usr/bin/env python3
"""Synthesize HomeRow's key sounds.

    Scripts/make-sounds.py [--out HomeRow/Resources/Sounds]

Every sample is computed here -- filtered noise, a few decaying sines -- so
the sounds are HomeRow's own and carry its licence; nothing is recorded or
borrowed.  The generator is seeded: running it again gives the same files,
byte for byte.  Standard library only.

A scheme is a folder: key-1..key-4.wav (played in turn, so that a run of
keys does not sound like a machine gun), space.wav, return.wav, error.wav.
16-bit mono, 44.1 kHz, a few kilobytes each.
"""
import argparse, math, os, random, struct, wave

RATE = 44100


def envelope(i, n, attack, decay):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def noise_burst(rng, seconds, decay, low, high):
    n = int(RATE * seconds)
    raw = [rng.uniform(-1, 1) * envelope(i, n, 0.0005, decay) for i in range(n)]
    return highpass(lowpass(raw, high), low)


def tone(seconds, partials, decay, attack=0.001):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        v = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-t / (decay * d)) for f, a, d in partials)
        out.append(v * min(1.0, t / attack))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def gain(samples, g):
    return [s * g for s in samples]


def write(path, samples, peak):
    top = max(1e-9, max(abs(s) for s in samples))
    # a few milliseconds of fade so that no file ends on a step
    n, fade = len(samples), int(RATE * 0.004)
    data = bytearray()
    for i, s in enumerate(samples):
        f = min(1.0, (n - i) / fade)
        data += struct.pack("<h", int(max(-1.0, min(1.0, s / top * peak * f)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


def click(rng, out):
    """A soft, dry key: a laptop or a membrane board."""
    for k in range(4):
        f = 1.0 + 0.06 * (k - 1.5)
        body = tone(0.03, [(210 * f, 0.6, 1.0)], 0.006)
        write(os.path.join(out, "key-%d.wav" % (k + 1)),
              mix(noise_burst(rng, 0.03, 0.004, 900 * f, 6000), body), 0.55)
    write(os.path.join(out, "space.wav"),
          mix(noise_burst(rng, 0.045, 0.007, 400, 3500), tone(0.045, [(140, 0.9, 1.0)], 0.010)), 0.6)
    write(os.path.join(out, "return.wav"),
          mix(noise_burst(rng, 0.05, 0.008, 500, 4000), tone(0.05, [(160, 0.9, 1.0)], 0.012)), 0.6)
    write(os.path.join(out, "error.wav"),
          tone(0.11, [(196, 1.0, 1.0), (185, 0.8, 1.0), (392, 0.25, 0.6)], 0.035, attack=0.003), 0.5)


def typewriter(rng, out):
    """A type bar against the platen, and a bell for Return."""
    for k in range(4):
        f = 1.0 + 0.05 * (k - 1.5)
        strike = noise_burst(rng, 0.07, 0.006, 1500 * f, 9000)
        ring = tone(0.07, [(1320 * f, 0.25, 1.0), (2110 * f, 0.18, 0.7), (330 * f, 0.5, 0.8)], 0.012)
        thud = gain(noise_burst(rng, 0.07, 0.015, 80, 500), 1.6)
        write(os.path.join(out, "key-%d.wav" % (k + 1)), mix(strike, ring, thud), 0.7)
    write(os.path.join(out, "space.wav"),
          mix(gain(noise_burst(rng, 0.09, 0.018, 70, 700), 1.8), noise_burst(rng, 0.05, 0.005, 1000, 5000)), 0.7)
    bell = tone(0.6, [(2093, 0.8, 1.0), (4186 * 1.003, 0.3, 0.5), (5540, 0.15, 0.3)], 0.16)
    carriage = gain(noise_burst(rng, 0.12, 0.03, 200, 2500), 0.7)
    write(os.path.join(out, "return.wav"), mix(bell, carriage), 0.6)
    write(os.path.join(out, "error.wav"),
          mix(gain(noise_burst(rng, 0.12, 0.03, 60, 400), 2.0), tone(0.12, [(110, 0.8, 1.0)], 0.04)), 0.6)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="HomeRow/Resources/Sounds")
    args = ap.parse_args()
    rng = random.Random(20260920)
    for name, make in (("click", click), ("typewriter", typewriter)):
        d = os.path.join(args.out, name)
        os.makedirs(d, exist_ok=True)
        make(rng, d)
    print("sounds written to", args.out)


if __name__ == "__main__":
    main()
