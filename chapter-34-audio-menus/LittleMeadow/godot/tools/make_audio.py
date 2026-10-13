"""Writes every sound of Little Meadow into res://assets/audio/.

Run:  python3 tools/make_audio.py [output_folder]
Needs numpy, scipy and ffmpeg (with libvorbis). The sounds are made from maths only,
with fixed random seeds, so a second run gives the same samples.
Licence of the result: CC0 1.0, see assets/audio/README_LICENSES.txt.
"""
import hashlib
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "assets" / "audio"


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def decay(t, tau):
    return np.exp(-t / tau)


def attack(n, ms):
    ramp = np.ones(n)
    k = min(n, int(SR * ms / 1000.0))
    if k > 0:
        ramp[:k] = np.linspace(0.0, 1.0, k)
    return ramp


def sine(freq, t, phase=0.0):
    return np.sin(2 * np.pi * freq * t + phase)


def sweep(f0, f1, t):
    total = t[-1] if len(t) else 1.0
    f = f0 * (f1 / f0) ** (t / total)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(n, rng):
    return rng.standard_normal(n)


def band(x, lo, hi, order=2):
    nyq = SR / 2.0
    if lo is None:
        sos = signal.butter(order, hi / nyq, "low", output="sos")
    elif hi is None:
        sos = signal.butter(order, lo / nyq, "high", output="sos")
    else:
        sos = signal.butter(order, [lo / nyq, hi / nyq], "band", output="sos")
    return signal.sosfilt(sos, x)


def normalise(x, peak_db=-3.0):
    top = np.max(np.abs(x))
    return x * (10 ** (peak_db / 20.0) / top) if top > 0 else x


def fade_edges(x, ms=4):
    k = int(SR * ms / 1000.0)
    x = x.copy()
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    return x


def place(buf, x, start, circular=False):
    n = len(buf)
    start = int(start)
    if circular:
        idx = (np.arange(len(x)) + start) % n
        np.add.at(buf, idx, x)
    else:
        end = min(n, start + len(x))
        if end > start:
            buf[start:end] += x[: end - start]


def bell(freq, seconds, tau, index=2.0, ratio=3.5):
    t = t_axis(seconds)
    mod = index * decay(t, tau * 0.5) * sine(freq * ratio, t)
    return sine(freq, t, mod) * decay(t, tau) * attack(len(t), 3)


def ding(freq, seconds=0.5, tau=0.12):
    t = t_axis(seconds)
    y = sine(freq, t) + 0.35 * sine(freq * 2.76, t) * decay(t, tau * 0.5) + 0.2 * sine(freq * 5.4, t) * decay(t, tau * 0.3)
    return y * decay(t, tau) * attack(len(t), 1.5)


def pluck(freq, seconds, tau=0.6, bright=1.0):
    t = t_axis(seconds)
    y = np.zeros_like(t)
    for k in range(1, 7):
        y += (1.0 / k) * sine(freq * k * (1 + 0.0004 * k), t) * decay(t, tau / (k ** (0.7 + 0.15 * bright)))
    return y * attack(len(t), 4)


def pad_voice(freq, seconds, rise=1.2, fall=1.8):
    t = t_axis(seconds)
    y = sine(freq, t) + 0.5 * sine(freq * 2.0, t, 0.3) + 0.2 * sine(freq * 3.0, t, 0.7)
    y += 0.6 * (sine(freq * 1.004, t) + sine(freq * 0.996, t))
    env = np.minimum(1.0, t / rise) * np.minimum(1.0, (seconds - t) / fall)
    return y * np.clip(env, 0, 1) ** 1.5


def reverb(x, rng, seconds=1.8, mix=0.25, circular=True):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (seconds / 5.0))
    ir = band(ir, 150, 6000)
    ir /= np.sqrt(np.sum(ir ** 2))
    if circular:
        wet = signal.fftconvolve(np.tile(x, 3), ir)[len(x): 2 * len(x)]
    else:
        wet = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - mix) + wet * mix


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def sfx_ui_click():
    t = t_axis(0.05)
    y = sine(1900, t) * decay(t, 0.008) + 0.4 * sine(1300, t) * decay(t, 0.015)
    return y


def sfx_ui_tick():
    t = t_axis(0.03)
    return sine(2600, t) * decay(t, 0.005)


def sfx_ui_open():
    t = t_axis(0.18)
    return sweep(520, 880, t) * decay(t, 0.09) * attack(len(t), 6)


def sfx_ui_close():
    t = t_axis(0.18)
    return sweep(880, 520, t) * decay(t, 0.09) * attack(len(t), 6)


def sfx_coin():
    a = ding(1568, 0.55, 0.14)
    b = np.zeros(int(SR * 0.55))
    place(b, a, 0)
    c = ding(2093, 0.5, 0.18)
    place(b, c, int(SR * 0.07))
    return b


def sfx_buy(rng):
    t = t_axis(0.2)
    pop = sweep(420, 190, t) * decay(t, 0.05) * attack(len(t), 2)
    rustle = band(noise(len(t), rng), 900, 3500) * decay(t, 0.06) * 0.35
    return pop + rustle


def sfx_sell(rng):
    t = t_axis(0.3)
    paper = band(noise(len(t), rng), 2500, 9000) * decay(t, 0.025) * 0.5
    ring = np.zeros(len(t))
    place(ring, ding(1175, 0.25, 0.08) * 0.7, int(SR * 0.03))
    return paper + ring


def sfx_unlock():
    out = np.zeros(int(SR * 1.1))
    for i, n in enumerate([72, 76, 79]):
        place(out, bell(midi(n), 0.8, 0.28, 1.2), int(SR * 0.11 * i))
    return out


def sfx_pickup():
    t = t_axis(0.12)
    return sweep(620, 1250, t) * decay(t, 0.05) * attack(len(t), 3)


def sfx_harvest(rng):
    t = t_axis(0.3)
    pop = sweep(340, 110, t) * decay(t, 0.05) * attack(len(t), 1.5)
    leaf = band(noise(len(t), rng), 1800, 7000) * decay(t, 0.07) * attack(len(t), 10) * 0.3
    return pop + leaf


def sfx_feed(rng):
    out = np.zeros(int(SR * 0.5))
    for i in range(3):
        t = t_axis(0.09)
        crunch = band(noise(len(t), rng), 1200, 5000) * decay(t, 0.02) * attack(len(t), 1)
        place(out, crunch * (1.0 - 0.15 * i), int(SR * (0.02 + 0.13 * i)))
    return out


def sfx_hoe(rng):
    t = t_axis(0.35)
    thud = sweep(150, 60, t) * decay(t, 0.07) * attack(len(t), 2)
    grit = band(noise(len(t), rng), 300, 2500) * decay(t, 0.09) * 0.6
    return thud + grit


def sfx_seed(rng):
    out = np.zeros(int(SR * 0.4))
    for i in range(7):
        t = t_axis(0.03)
        tick = band(noise(len(t), rng), 2500, 7000) * decay(t, 0.006)
        place(out, tick * rng.uniform(0.4, 1.0), int(SR * (0.01 + 0.045 * i + rng.uniform(0, 0.02))))
    return out


def sfx_water(rng):
    t = t_axis(1.0)
    body = band(noise(len(t), rng), 500, 2600)
    wobble = 0.65 + 0.35 * sine(23, t) * sine(7.3, t, 1.0)
    glug = sweep(300, 520, t) * 0.18 * (0.5 + 0.5 * sine(11, t))
    env = attack(len(t), 80) * np.clip((1.0 - t) / 0.25, 0, 1)
    return (body * wobble + glug) * env


def sfx_hammer(rng):
    out = np.zeros(int(SR * 0.45))
    for i, gap in enumerate([0.0, 0.16]):
        t = t_axis(0.3)
        knock = (sine(210, t) + 0.6 * sine(470, t, 0.4) + 0.3 * sine(910, t, 1.1)) * decay(t, 0.045)
        click = band(noise(len(t), rng), 1500, 6000) * decay(t, 0.004) * 0.7
        place(out, (knock + click) * (1.0 - 0.2 * i), int(SR * gap))
    return out


def sfx_crunch(rng):
    out = np.zeros(int(SR * 0.5))
    for i in range(9):
        t = t_axis(0.08)
        grain = band(noise(len(t), rng), 400, 4500) * decay(t, 0.018)
        place(out, grain * (1.0 - 0.09 * i) * rng.uniform(0.6, 1.0), int(SR * (0.03 * i + rng.uniform(0, 0.015))))
    return out


def sfx_denied():
    t = t_axis(0.28)
    return (sweep(150, 85, t) + 0.3 * sine(300, t)) * decay(t, 0.07) * attack(len(t), 4)


def sfx_footstep(rng):
    t = t_axis(0.14)
    thump = band(noise(len(t), rng), 80, 700) * decay(t, 0.035) * attack(len(t), 3)
    blades = band(noise(len(t), rng), 2500, 8000) * decay(t, 0.03) * attack(len(t), 6) * 0.18
    return thump + blades


def sfx_chime():
    out = np.zeros(int(SR * 3.2))
    for i, n in enumerate([79, 76, 83, 88]):
        place(out, bell(midi(n), 2.4, 0.7, 1.4) * (0.9 - 0.12 * i), int(SR * 0.42 * i))
    return out


def sfx_save():
    out = np.zeros(int(SR * 0.7))
    place(out, bell(midi(72), 0.5, 0.15, 0.8), 0)
    place(out, bell(midi(79), 0.5, 0.2, 0.8), int(SR * 0.1))
    return out


def sfx_load():
    out = np.zeros(int(SR * 0.7))
    place(out, bell(midi(79), 0.5, 0.15, 0.8), 0)
    place(out, bell(midi(72), 0.5, 0.2, 0.8), int(SR * 0.1))
    return out


def shaped_noise(n, rng, lo, hi, slope=0.0):
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    gain = np.zeros_like(f)
    inside = (f >= lo) & (f <= hi)
    gain[inside] = (np.maximum(f[inside], 1.0) / 1000.0) ** slope
    edge = 0.15
    gain *= 1.0 / (1.0 + np.exp((lo - f) / (lo * edge))) * 1.0 / (1.0 + np.exp((f - hi) / (hi * edge)))
    y = np.fft.irfft(spec * gain, n)
    return y / np.max(np.abs(y))


def loop_rain(rng):
    n = int(SR * 24)
    bed = shaped_noise(n, rng, 400, 9000, -0.6)
    hiss = shaped_noise(n, rng, 3000, 14000, -0.2) * 0.35
    drops = np.zeros(n)
    for _ in range(int(24 * 90)):
        start = rng.integers(0, n)
        k = int(SR * 0.012)
        tt = np.arange(k) / SR
        d = band(rng.standard_normal(k), 2500, 9000, 1) * np.exp(-tt / 0.003)
        place(drops, d * rng.uniform(0.2, 1.0), start, circular=True)
    drops /= np.max(np.abs(drops))
    mix = bed * 0.8 + hiss + drops * 0.45
    slow = 1.0 + 0.08 * sine(1 / 12.0, t_axis(24)) + 0.05 * sine(1 / 8.0, t_axis(24), 1.3)
    return mix * slow


def chirp(rng):
    dur = rng.uniform(0.06, 0.14)
    t = t_axis(dur)
    f0 = rng.uniform(2200, 4200)
    shape = rng.choice([-1, 1]) * rng.uniform(300, 1200)
    f = f0 + shape * np.sin(np.pi * t / dur) + rng.uniform(-400, 400) * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.3 * np.sin(2 * ph)
    return y * np.sin(np.pi * t / dur) ** 1.5


def loop_birds(rng):
    length = 32
    n = int(SR * length)
    t = t_axis(length)
    wind = shaped_noise(n, rng, 120, 1600, -1.0) * (0.55 + 0.25 * sine(1 / 16.0, t) + 0.12 * sine(3 / 32.0, t, 0.7))
    birds = np.zeros(n)
    centres = np.sort(rng.uniform(0, length, 26))
    for c in centres:
        phrase = rng.integers(1, 5)
        for j in range(phrase):
            place(birds, chirp(rng) * rng.uniform(0.25, 0.7), int(SR * (c + 0.13 * j)), circular=True)
    mix = wind * 0.45 + birds * 0.5
    return reverb(mix, rng, 1.0, 0.2)


def loop_crickets(rng):
    length = 20
    n = int(SR * length)
    t = t_axis(length)
    out = np.zeros(n)
    for freq, rate, ph in [(4300, 2.0, 0.0), (4600, 2.5, 0.3), (3900, 1.5, 0.6), (5000, 3.0, 0.1)]:
        cycles = int(rate * length)
        pulse_rate = 38.0
        slow = (np.sin(2 * np.pi * (cycles / length) * t + 2 * np.pi * ph) > 0.2).astype(float)
        slow = np.convolve(slow, np.ones(400) / 400, mode="same")
        fast = 0.5 + 0.5 * np.sin(2 * np.pi * round(pulse_rate * length) / length * t)
        carrier = np.sin(2 * np.pi * freq * t + 0.4 * np.sin(2 * np.pi * 50 * t))
        out += carrier * fast ** 2 * slow * 0.5
    wind = shaped_noise(n, rng, 100, 900, -1.0) * 0.12
    return reverb(out * 0.6 + wind, rng, 0.8, 0.15)


def music(seed, bpm, bars, key_root, scale, chords, density, bell_lead, name):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat
    n = int(total * SR)
    buf = np.zeros(n)
    bar_len = 4 * beat
    chord_bars = 2
    for b in range(0, bars, chord_bars):
        chord = chords[(b // chord_bars) % len(chords)]
        for degree in chord["pad"]:
            voice = pad_voice(midi(degree), chord_bars * bar_len + 1.0, 1.4, 2.2)
            place(buf, voice * 0.10, int(b * bar_len * SR), circular=True)
        for k in range(chord_bars * 2):
            root = chord["bass"]
            place(buf, pluck(midi(root), 1.4, 0.7, 0.2) * 0.22, int((b * 4 + k * 2) * beat * SR), circular=True)
    notes = [key_root + s for s in scale] + [key_root + 12 + s for s in scale]
    pos = len(scale) // 2
    motif = []
    for step in range(16):
        if rng.random() < density:
            pos = int(np.clip(pos + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(notes) - 1))
            motif.append((step, notes[pos]))
    for bar in range(0, bars):
        phrase = motif if (bar // 2) % 4 != 3 else [(s, notes[int(np.clip(notes.index(nn) + rng.choice([-1, 0, 1]), 0, len(notes) - 1))]) for s, nn in motif]
        if bar % 2 == 1:
            phrase = [(s, nn) for s, nn in phrase if s % 2 == 0] or phrase
        for step, nn in phrase:
            when = (bar * 4 + step * 0.25 * (2 if bell_lead else 1)) * beat
            if when >= total:
                continue
            tone = bell(midi(nn), 3.0, 1.1, 0.9) if bell_lead else pluck(midi(nn), 1.6, 0.5, 1.0)
            place(buf, tone * rng.uniform(0.10, 0.17), int(when * SR), circular=True)
    buf = reverb(buf, rng, 2.2, 0.3)
    buf = band(buf, 60, 11000, 1)
    return buf


def write_wav(path, x):
    pcm = np.int16(np.clip(x, -1, 1) * 32767)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path, x, quality):
    raw = np.int16(np.clip(x, -1, 1) * 32767).tobytes()
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(quality), "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)]
    subprocess.run(cmd, input=raw, check=True)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(34)
    sfx = {
        "ui_click": sfx_ui_click(), "ui_tick": sfx_ui_tick(), "ui_open": sfx_ui_open(), "ui_close": sfx_ui_close(),
        "coin": sfx_coin(), "buy": sfx_buy(rng), "sell": sfx_sell(rng), "unlock": sfx_unlock(),
        "pickup": sfx_pickup(), "harvest": sfx_harvest(rng), "feed": sfx_feed(rng),
        "hoe": sfx_hoe(rng), "seed": sfx_seed(rng), "water": sfx_water(rng),
        "hammer": sfx_hammer(rng), "crunch": sfx_crunch(rng), "denied": sfx_denied(),
        "footstep": sfx_footstep(rng), "chime": reverb(sfx_chime(), rng, 2.0, 0.3, circular=False),
        "save": sfx_save(), "load": sfx_load(),
    }
    report = {}
    for name, x in sfx.items():
        y = fade_edges(normalise(x, -4.0), 3)
        path = OUT / f"sfx_{name}.wav"
        write_wav(path, y)
        report[path.name] = {"seconds": round(len(y) / SR, 3), "peak_db": round(20 * np.log10(np.max(np.abs(y))), 1)}
    loops = {
        "amb_rain": (loop_rain(rng), 3, -26.0),
        "amb_birds": (loop_birds(rng), 3, -28.0),
        "amb_crickets": (loop_crickets(rng), 3, -30.0),
    }
    day = music(3401, 88, 24, 60, [0, 2, 4, 7, 9],
                [{"pad": [48, 55, 64], "bass": 36}, {"pad": [45, 52, 60], "bass": 33},
                 {"pad": [53, 60, 69], "bass": 41}, {"pad": [55, 62, 67], "bass": 43}], 0.55, False, "day")
    night = music(3402, 60, 16, 57, [0, 3, 5, 7, 10],
                  [{"pad": [45, 52, 60], "bass": 33}, {"pad": [41, 48, 57], "bass": 29},
                   {"pad": [48, 55, 64], "bass": 36}, {"pad": [43, 50, 59], "bass": 31}], 0.4, True, "night")
    loops["music_day"] = (day, 4, -22.0)
    loops["music_night"] = (night, 4, -24.0)
    for name, (x, quality, rms_db) in loops.items():
        x = x - np.mean(x)
        x = x * (10 ** (rms_db / 20.0) / np.sqrt(np.mean(x ** 2)))
        if np.max(np.abs(x)) > 0.95:
            x = x * 0.95 / np.max(np.abs(x))
        path = OUT / f"{name}.ogg"
        write_ogg(path, x, quality)
        report[path.name] = {"seconds": round(len(x) / SR, 3), "rms_db": rms_db, "peak_db": round(20 * np.log10(np.max(np.abs(x))), 1)}
    for path in sorted(OUT.glob("*")):
        if path.suffix in (".wav", ".ogg"):
            report[path.name]["bytes"] = path.stat().st_size
            report[path.name]["sha256"] = sha256(path)
    (Path(__file__).resolve().parent / "audio_report.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    total = sum(v["bytes"] for v in report.values())
    print("files", len(report), "bytes", total)


if __name__ == "__main__":
    main()
