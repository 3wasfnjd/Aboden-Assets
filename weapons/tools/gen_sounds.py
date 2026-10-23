#!/usr/bin/env python3
"""The sounds of the v1.2 playful weapons (AB-W-013 ... 022), synthesised offline into
addons/aboden_blaster/sounds/ in the format of the other files there: mono, 22050 Hz, 16-bit WAV,
at about the level of the original game's SFX (RMS 0.01-0.04, peaks well under full scale, as the
web SFX bus left them; AbodenBlasterAudio plays every file at 0 dB).

  python3 tools/gen_sounds.py [name-filter]

numpy only. Every variant is seeded, so a re-render writes the same files. The first 59 files
came from the original game (its Web Audio code rendered in a headless browser, and a numpy
script for the firework cues); these follow the same recipe: noise, filters, sweeps and
envelopes, nothing recorded.

  flap_1..3          wing beats: two or three soft whumps of band-passed air (falcon launch, catch)
  screech_1..2       a falcon's short "kee-eer": a falling harsh tone with vibrato (its dive)
  ice_zap_1..3       the freeze ray: a glassy falling zap with a sparkle on top
  ice_crack_1..3     ice cracking: sharp clicks, a crunchy burst and a tinkle
  whoomp_1..2        the black hole's implosion: an inhaling swell, then a deep falling thud
  put_1..3           the date blaster's soft "put" (it fires ten times a second: kept quiet)
  ember              the bakhoor setting down: a soft crackle and sizzle
  snap_1..3          the lasso catching: a whip-crack snap and a low thwack
  hose_hiss_1..3     a burst of the hose's stream: gurgling band-passed hiss
  cluster_pop_1..3   a little bomb going off: a cartoon pop and a short bang
  zing_1..2          the magnet: a metallic zing with a mains hum under it
  shield_up          the shield bubble opening: a rising shimmering chord
  shield_block_1..3  the shield stopping a projectile: a "bwong" ping and a soft thud
"""
import os
import struct
import sys

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "addons", "aboden_blaster", "sounds")


# --- building blocks ------------------------------------------------------------------------

def tt(dur):
    return np.arange(int(dur * SR)) / SR


def biquad(x, kind, f, q=0.707):
    """RBJ biquad over x; f (Hz) and q may be arrays (time-varying) or scalars."""
    n = len(x)
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    q = np.broadcast_to(np.asarray(q, dtype=float), (n,))
    w = 2 * np.pi * np.clip(f, 20, SR * 0.45) / SR
    cw, sw = np.cos(w), np.sin(w)
    a = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # band-pass, 0 dB peak
        b0, b1, b2 = a, np.zeros(n), -a
    a0, a1, a2 = 1 + a, -2 * cw, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        xi = x[i]
        yi = b0[i] * xi + b1[i] * x1 + b2[i] * x2 - a1[i] * y1 - a2[i] * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def env(t, attack, decay, start=0.0):
    """A linear attack then an exponential decay (time constant `decay`), from `start`."""
    u = t - start
    e = np.where(u < attack, u / max(attack, 1e-6), np.exp(-(u - attack) / decay))
    return np.where(u < 0, 0.0, e)


def sweep(t, f0, f1, curve=1.0):
    """A sine whose frequency glides from f0 to f1 over the length of t (exponential glide)."""
    u = (t / t[-1]) ** curve
    f = f0 * (f1 / f0) ** u
    return np.sin(2 * np.pi * np.cumsum(f) / SR), f


def limit(x, peak, rms=None):
    """Scales to `peak` (and, if given, no louder than `rms`), with a soft knee."""
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.4) / np.tanh(1.4)
    x = x * peak
    if rms is not None:
        r = np.sqrt(np.mean(x ** 2))
        if r > rms:
            x *= rms / r
    return x


def fade(x, ms=6):
    n = int(ms * SR / 1000)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name, x):
    x = fade(np.asarray(x, dtype=float))
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    head = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE"
    head += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16)
    head += b"data" + struct.pack("<I", len(pcm))
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(head + pcm)
    print("%-16s %.2f s  peak %.3f  rms %.3f" % (name, len(x) / SR, np.max(np.abs(x)), np.sqrt(np.mean(x ** 2))))


# --- the sounds -----------------------------------------------------------------------------

def flap(rng):
    t = tt(0.34)
    out = np.zeros_like(t)
    beats = rng.integers(2, 4)
    for b in range(beats):
        at = 0.02 + b * (0.09 + rng.uniform(-0.01, 0.015))
        n = rng.standard_normal(len(t))
        body = biquad(n, "bp", 420 + rng.uniform(-60, 80) + 500 * env(t, 0.005, 0.04, at), 0.9)
        out += body * env(t, 0.012, 0.035, at) * (1.0 - 0.25 * b)
    air = biquad(rng.standard_normal(len(t)), "bp", 1600, 0.6) * env(t, 0.05, 0.12, 0.01) * 0.25
    return limit(out + air, 0.15, 0.03)


def screech(rng):
    t = tt(0.46)
    f = (2900 + rng.uniform(-150, 150)) * (0.74 ** (t / t[-1])) * (1 + 0.025 * np.sin(2 * np.pi * 31 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = sum(np.sin(ph * h) / h ** 1.2 for h in range(1, 6))
    rasp = biquad(rng.standard_normal(len(t)), "bp", f * 1.1, 4.0) * 0.5
    x = (tone + rasp) * env(t, 0.025, 0.16, 0.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t) ** 2)
    return limit(biquad(x, "hp", 900), 0.12, 0.028)


def ice_zap(rng):
    t = tt(0.26)
    s1, f = sweep(t, 4200 + rng.uniform(-300, 300), 1400, 0.6)
    fm = np.sin(2 * np.pi * np.cumsum(f * 1.5 + 300 * np.sin(2 * np.pi * 40 * t)) / SR)
    sparkle = biquad(rng.standard_normal(len(t)), "hp", 6000) * (rng.random(len(t)) < 0.02) * 2.0
    hiss = biquad(rng.standard_normal(len(t)), "bp", 5000, 1.5) * 0.3
    x = (s1 * 0.7 + fm * 0.35) * env(t, 0.004, 0.07) + (sparkle + hiss) * env(t, 0.01, 0.1)
    return limit(x, 0.12, 0.025)


def ice_crack(rng):
    t = tt(0.42)
    x = np.zeros_like(t)
    for _ in range(rng.integers(4, 7)):
        at = rng.uniform(0.0, 0.12)
        i = int(at * SR)
        click = np.zeros_like(t)
        click[i:i + 3] = rng.uniform(0.6, 1.0) * np.array([1.0, -0.7, 0.3])
        x += biquad(click, "bp", rng.uniform(2500, 5000), 3.0) * 6.0
    crunch = biquad(rng.standard_normal(len(t)), "bp", 2200, 0.8) * env(t, 0.003, 0.05) * 0.8
    tink = sum(np.sin(2 * np.pi * fr * t) * env(t, 0.002, 0.09, rng.uniform(0.01, 0.08)) for fr in rng.uniform(3200, 6400, 3)) * 0.25
    return limit(x + crunch + tink, 0.2, 0.035)


def whoomp(rng):
    t = tt(0.8)
    inhale = biquad(rng.standard_normal(len(t)), "lp", 200 + 2400 * np.clip(t / 0.2, 0, 1) ** 2, 1.2)
    inhale *= np.clip(t / 0.2, 0, 1) ** 2 * (t < 0.22)
    tb = np.clip(t - 0.2, 0, None)
    f = 110 * np.exp(-tb / 0.12) + 38 + rng.uniform(-3, 3)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(t, 0.006, 0.22, 0.2)
    body = biquad(rng.standard_normal(len(t)), "lp", 300, 0.8) * env(t, 0.004, 0.12, 0.2) * 0.8
    return limit(inhale * 0.35 + sub + body, 0.32, 0.06)


def put(rng):
    t = tt(0.12)
    s, _ = sweep(t, 240 + rng.uniform(-30, 30), 110, 0.5)
    click = biquad(rng.standard_normal(len(t)), "lp", 1400, 0.7) * env(t, 0.001, 0.008)
    x = s * env(t, 0.002, 0.03) + click * 0.6
    return limit(x, 0.085, 0.018)


def ember(rng):
    t = tt(0.65)
    sizzle = biquad(rng.standard_normal(len(t)), "hp", 3500) * env(t, 0.06, 0.25) * 0.4
    crackle = np.zeros_like(t)
    for at in rng.uniform(0.0, 0.5, 14):
        i = int(at * SR)
        crackle[i] = rng.uniform(0.4, 1.0) * rng.choice([-1, 1])
    crackle = biquad(crackle, "bp", 2600, 1.5) * 5.0
    thud = np.sin(2 * np.pi * 150 * t) * env(t, 0.003, 0.03) * 0.6
    return limit(sizzle + crackle + thud, 0.07, 0.014)


def snap(rng):
    t = tt(0.22)
    crack = biquad(rng.standard_normal(len(t)), "bp", 3000 + rng.uniform(-400, 600), 1.2) * env(t, 0.0015, 0.018)
    swish = biquad(rng.standard_normal(len(t)), "bp", 1200 + 3000 * (1 - t / t[-1]), 1.0) * env(t, 0.04, 0.03) * 0.25 * (t < 0.06)
    thwack = np.sin(2 * np.pi * (170 + rng.uniform(-20, 20)) * t) * env(t, 0.002, 0.04, 0.005) * 0.7
    return limit(crack + swish + thwack, 0.24, 0.04)


def hose_hiss(rng):
    t = tt(0.18)
    n = rng.standard_normal(len(t))
    gurgle = 0.6 + 0.4 * np.sin(2 * np.pi * (23 + rng.uniform(-4, 4)) * t + rng.uniform(0, 6))
    x = (biquad(n, "bp", 2600, 0.6) + biquad(n, "bp", 700 + 300 * gurgle, 2.0) * 0.4) * gurgle
    x *= np.minimum(1.0, t / 0.012) * np.minimum(1.0, (t[-1] - t) / 0.05)
    return limit(x, 0.06, 0.016)


def cluster_pop(rng):
    t = tt(0.36)
    pop, _ = sweep(t[: int(0.04 * SR)], 700 + rng.uniform(-80, 80), 220)
    pop = np.concatenate([pop, np.zeros(len(t) - len(pop))]) * env(t, 0.001, 0.02)
    bang = biquad(rng.standard_normal(len(t)), "lp", 1800 * np.exp(-t / 0.08) + 200, 0.9) * env(t, 0.002, 0.06, 0.012)
    thud = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t / 0.1) + 50) / SR) * env(t, 0.003, 0.08, 0.01) * 0.8
    return limit(pop * 0.7 + bang + thud, 0.2, 0.04)


def zing(rng):
    t = tt(0.55)
    slide = 1.0 + 0.12 * (1 - np.exp(-t / 0.05))
    x = np.zeros_like(t)
    for fr, a, d in [(880, 1.0, 0.18), (2420, 0.55, 0.1), (4150, 0.3, 0.06), (1330, 0.4, 0.14)]:
        fr = fr * (1 + rng.uniform(-0.02, 0.02))
        x += a * np.sin(2 * np.pi * np.cumsum(fr * slide) / SR) * env(t, 0.003, d)
    hum = (np.sin(2 * np.pi * 60 * t) + 0.5 * np.sin(2 * np.pi * 120 * t) + 0.3 * np.sign(np.sin(2 * np.pi * 60 * t))) * env(t, 0.03, 0.2) * 0.25
    return limit(x + hum, 0.12, 0.025)


def shield_up(rng):
    t = tt(0.55)
    x = np.zeros_like(t)
    for base in [440, 554, 659, 880]:
        f = base * (2 ** (np.clip(t / 0.35, 0, 1) * 1.0)) * (1 + 0.004 * np.sin(2 * np.pi * 6 * t + base))
        x += np.sin(2 * np.pi * np.cumsum(f) / SR)
    shimmer = biquad(rng.standard_normal(len(t)), "hp", 7000) * 0.15
    x = (x * (0.7 + 0.3 * np.sin(2 * np.pi * 14 * t)) + shimmer) * env(t, 0.12, 0.18, 0.0)
    return limit(x, 0.12, 0.028)


def shield_block(rng):
    t = tt(0.4)
    f0 = 1150 + rng.uniform(-120, 120)
    bend = 1 - 0.18 * (1 - np.exp(-t / 0.06))
    ping = np.sin(2 * np.pi * np.cumsum(f0 * bend) / SR) * env(t, 0.002, 0.11)
    ping += 0.5 * np.sin(2 * np.pi * np.cumsum(f0 * 1.53 * bend) / SR) * env(t, 0.002, 0.07)
    thud = biquad(rng.standard_normal(len(t)), "lp", 500, 0.8) * env(t, 0.002, 0.03) * 0.8
    return limit(ping + thud, 0.18, 0.035)


SOUNDS = [
    ("flap", 3, flap, 11), ("screech", 2, screech, 12), ("ice_zap", 3, ice_zap, 13), ("ice_crack", 3, ice_crack, 14),
    ("whoomp", 2, whoomp, 15), ("put", 3, put, 16), ("ember", 0, ember, 17), ("snap", 3, snap, 18),
    ("hose_hiss", 3, hose_hiss, 19), ("cluster_pop", 3, cluster_pop, 20), ("zing", 2, zing, 21),
    ("shield_up", 0, shield_up, 22), ("shield_block", 3, shield_block, 23),
]


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    os.makedirs(OUT, exist_ok=True)
    for name, n, fn, seed in SOUNDS:
        if only and only not in name:
            continue
        if n == 0:
            write(name, fn(np.random.default_rng(seed * 100)))
        for i in range(n):
            write("%s_%d" % (name, i + 1), fn(np.random.default_rng(seed * 100 + i + 1)))


if __name__ == "__main__":
    main()
