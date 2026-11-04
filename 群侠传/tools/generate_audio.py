"""Generate original, quiet pentatonic placeholder music and game cues (stdlib only)."""
import math
from pathlib import Path
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "Audio"


def render(name, duration, notes):
    samples = [0.0] * int(duration * RATE)
    for start, frequency, length, gain in notes:
        for i in range(int(length * RATE)):
            pos = int(start * RATE) + i
            if pos >= len(samples):
                break
            t = i / RATE
            envelope = min(1, t / .008) * math.exp(-4 * t / length)
            envelope *= min(1, (length - t) / .04)
            tone = math.sin(math.tau * frequency * t) + .22 * math.sin(math.tau * frequency * 2 * t)
            samples[pos] += gain * envelope * tone
    with wave.open(str(OUT / (name + ".wav")), "wb") as target:
        target.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        target.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 26000)) for x in samples))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    melody = [60, 64, 67, 69, 67, 64, 62, 60, 62, 64, 67, 72, 69, 67, 64, 62]
    notes = [(i * 1.0, 440 * 2 ** ((note - 69) / 12), 2.0, .32) for i, note in enumerate(melody)]
    notes += [(i * 4.0, 130.81 if i % 2 == 0 else 98, 3.5, .18) for i in range(4)]
    render("jianghu", 18, notes)
    render("click", .12, [(0, 880, .1, .23)])
    render("attack", .32, [(0, 130, .25, .48), (.02, 390, .14, .2)])
    render("heal", .6, [(0, 523.25, .4, .3), (.15, 659.25, .4, .3)])
    render("victory", 1.5, [(i * .2, f, .6, .3) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5])])
    render("defeat", 1.4, [(i * .25, f, .6, .3) for i, f in enumerate([392, 329.63, 261.63])])
    print("Generated 6 original audio files")
