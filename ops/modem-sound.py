#!/usr/bin/env python3
"""Generate and play a modem handshake sound with per-machine variation.
Usage: modem-sound.py [seed 0-7]
Each seed produces a distinct but recognizable modem/data-transfer sound."""
import struct, wave, math, subprocess, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 0
sr = 44100
dur = 5
frames = sr * dur
wav_path = "/tmp/modem-handshake.wav"

# Per-machine frequency/timing variation
PROFILES = [
    # (dial_freq, carrier_freq, sweep_speed, chirp_rate, final_tone)
    (350, 2100, 25, 60, 1800),   # 0: Classic 56k modem
    (440, 2400, 35, 80, 2000),   # 1: High-pitched fast handshake
    (280, 1800, 18, 40, 1500),   # 2: Low rumbling modem
    (400, 2200, 45, 100, 1900),  # 3: Aggressive rapid negotiation
    (320, 1950, 22, 50, 1700),   # 4: Vintage 28.8k style
    (380, 2300, 30, 70, 2100),   # 5: Sharp digital chirps
    (300, 2000, 20, 55, 1600),   # 6: Deep bass tones
    (420, 2500, 40, 90, 2200),   # 7: Sci-fi high frequency
]

dial_f, carrier_f, sweep_spd, chirp_rate, final_f = PROFILES[seed % 8]
dial_f2 = dial_f + 90  # Second DTMF tone

w = wave.open(wav_path, "w")
w.setnchannels(1)
w.setsampwidth(2)
w.setframerate(sr)
data = b""

for i in range(frames):
    t = i / sr

    if t < 0.8:
        # Dial tone (dual-tone)
        sample = int(8000 * (math.sin(2*math.pi*dial_f*t) + math.sin(2*math.pi*dial_f2*t)))
    elif t < 1.2:
        # Carrier detect (CED tone)
        sample = int(14000 * math.sin(2*math.pi*carrier_f*t))
    elif t < 2.0:
        # Handshake — alternating frequencies
        freq = 1200 + 1200 * (0.5 + 0.5 * math.sin(2*math.pi*sweep_spd*t))
        sample = int(12000 * math.sin(2*math.pi*freq*t))
    elif t < 3.0:
        # Scrambled negotiation — rapid frequency sweeps
        freq = 300 + 2100 * abs(math.sin(2*math.pi*chirp_rate*t))
        noise = 3000 * math.sin(2*math.pi*(800+400*math.sin(2*math.pi*15*t))*t)
        sample = int(10000 * math.sin(2*math.pi*freq*t) + noise)
    elif t < 4.0:
        # Training — chirps and warbles
        freq = 600 + 1800 * (0.5 + 0.5 * math.sin(2*math.pi*(chirp_rate*0.6)*t))
        amp = 8000 + 4000 * math.sin(2*math.pi*3*t)
        sample = int(amp * math.sin(2*math.pi*freq*t))
    else:
        # Final sync — settling carrier fading out
        fade = max(0, 1.0 - (t - 4.0) * 1.0)
        sample = int(12000 * fade * math.sin(2*math.pi*final_f*t))

    sample = max(-32768, min(32767, sample))
    data += struct.pack("<h", sample)

w.writeframes(data)
w.close()

subprocess.Popen(["afplay", wav_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
