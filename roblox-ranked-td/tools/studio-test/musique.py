# MUSIQUE de la vidéo de la page du jeu (montage.py) : un morceau original de 16 s, fabriqué ici note par note avec
# numpy (aucun son pris ailleurs : il est à nous, libre de droits). Demande du propriétaire (04/10/2026) : « enlève
# le volume du jeu et mets ta propre musique » (le son du jeu sautait à chaque changement de plan).
#   python tools/studio-test/musique.py --sortie musique.wav      (pour l'écouter seule ; --niveaux : le volume de
#   chaque groupe d'instruments)
# 150 battements par minute : un temps = 0,4 s, une mesure = 1,6 s, 10 mesures = 16 s. Chaque plan de la vidéo dure
# 2 mesures : les changements de plan tombent sur un premier temps, avec un « whoosh » pendant le fondu d'image.
#   mesures 1-2   le colosse  : la mineur, fa ; boum au début, l'intro s'ouvre (filtre), arpège de clochettes
#   mesures 3-4   le glacier  : do, sol ; la batterie entière, la basse qui roule, la mélodie
#   mesures 5-6   l'œuf       : la mineur, fa ; la mélodie plus haut, les clochettes, un scintillement à l'éclosion
#   mesures 7-8   le boss     : ré mineur, mi majeur ; boum, accords de cuivres et toms en 3 + 3 + 2, roulement
#   mesures 9-10  la victoire : la MAJEUR ; un accent quand le panneau apparaît, le dernier accord qui résonne
# (montage.py fait apparaître l'œuf ouvert et le panneau de victoire un temps après le début de leur plan : SPARKLE,
# VICTORY)
import argparse
import wave

import numpy as np

SR = 48000
BPM = 150
BEAT = 60 / BPM      # 0,4 s
BAR = 4 * BEAT       # 1,6 s
BARS = 10
LENGTH = BARS * BAR  # 16 s
TAIL = 2.0           # s : la résonance après la fin (coupée)

# Les accords (notes MIDI : 60 = le do du milieu du piano), la note de basse de chaque accord, l'accord de chaque
# mesure, la mélodie (par mesure : position et durée en croches, note), les arpèges (doubles croches).
CHORDS = {
    'Am': (57, 60, 64, 69), 'F': (53, 57, 60, 65), 'C': (55, 60, 64, 67), 'G': (55, 59, 62, 67),
    'Dm': (53, 57, 62, 65), 'E': (52, 56, 59, 64), 'A': (57, 61, 64, 69),
}
ROOTS = {'Am': 33, 'F': 29, 'C': 36, 'G': 31, 'Dm': 38, 'E': 28, 'A': 33}
SONG = ['Am', 'F', 'C', 'G', 'Am', 'F', 'Dm', 'E', 'A', 'A']
MELODY = {
    3: [(0, 1, 67), (1, 1, 72), (2, 2, 76), (4, 1, 74), (5, 1, 76), (6, 2, 79)],
    4: [(0, 3, 79), (3, 1, 77), (4, 1, 76), (5, 1, 74), (6, 2, 71)],
    5: [(0, 1, 72), (1, 1, 76), (2, 2, 81), (4, 1, 79), (5, 1, 81), (6, 2, 83)],
    6: [(0, 3, 84), (3, 1, 81), (4, 1, 79), (5, 1, 77), (6, 2, 76)],
    7: [(0, 3, 74), (3, 3, 77), (6, 2, 81)],
    8: [(0, 3, 80), (3, 3, 76), (6, 2, 83)],
    9: [(0, 4, 85), (4, 1, 83), (5, 1, 85), (6, 2, 88)],
    10: [(0, 7, 81)],
}
ARPS = {1: (57, 60, 64, 69), 2: (53, 57, 60, 65), 5: (69, 72, 76, 81), 6: (65, 69, 72, 77), 9: (69, 73, 76, 81)}
# Le « whoosh » de chaque changement de plan (mesure : -1 de la droite vers la gauche, 0 au milieu), comme les
# transitions de montage.py : l'image glisse à gauche, vers le haut, flash blanc, à gauche.
WHOOSHES = {3: -1, 5: 0, 7: 0, 9: -1}
SPARKLE = 4 * BAR + BEAT   # 6,8 s : l'œuf s'ouvre
VICTORY = 8 * BAR + BEAT   # 13,2 s : le panneau de victoire

rng = np.random.default_rng(2026)  # (toujours le même morceau)


def at(seconds):
    return int(round(seconds * SR))


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def pan_gains(pan):
    """Gauche / droite d'un son placé de -1 (à gauche) à 1 (à droite) ; au milieu, 1 des deux côtés."""
    angle = (np.clip(pan, -1, 1) + 1) * np.pi / 4
    return np.cos(angle) * np.sqrt(2), np.sin(angle) * np.sqrt(2)


def edges(signal, fade_in=0.001, fade_out=0.005):
    """Début et fin adoucis (pas de clic)."""
    a, b = at(fade_in), at(fade_out)
    if a:
        signal[:a] *= np.linspace(0, 1, a)
    if b:
        signal[-b:] *= np.linspace(1, 0, b)
    return signal


def spectral(signal, low=None, high=None, order=2):
    """Filtre fait par FFT (sans décalage) : garde ce qui est au-dessus de `low` Hz et sous `high` Hz."""
    freqs = np.fft.rfftfreq(len(signal), 1 / SR)
    gain = np.ones_like(freqs)
    if high:
        gain = gain / np.sqrt(1 + (freqs / high) ** (2 * order))
    if low:
        gain = gain / np.sqrt(1 + (low / np.maximum(freqs, 1e-3)) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(signal) * gain, len(signal))


def convolve(signal, response):
    size = len(signal) + len(response) - 1
    nfft = 1 << (size - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(signal, nfft) * np.fft.rfft(response, nfft), nfft)[:len(signal)]


def adsr(gate, release, attack=0.005, decay=0.1, sustain=0.8):
    """Enveloppe d'une note : montée, descente vers le maintien pendant `gate` s, puis extinction en `release` s."""
    n = at(gate + release)
    t = np.arange(n) / SR
    env = np.minimum(t / attack, 1) * (sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / decay))
    held = at(gate)
    if n > held:
        env[held:] *= np.cos(np.linspace(0, np.pi / 2, n - held)) ** 2
    return env


def oscillator(freq, seconds, shape='saw', cutoff=None, detune=0.0, vibrato=0.0, offset=0.0, order=3):
    """Une onde sans repliement (somme d'harmoniques) : 'saw' (dents de scie), 'square' (carrée) ou 'sine' ;
    cutoff : un filtre passe-bas (fréquence fixe, ou une courbe aussi longue que la note ; 18 dB par octave)."""
    n = at(seconds)
    t = np.arange(n) / SR
    f = freq * 2 ** (detune / 1200)
    rate = np.full(n, f)
    if vibrato:
        rate = rate * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.25, 0, 1))
    phase = offset + 2 * np.pi * np.cumsum(rate) / SR
    if shape == 'sine':
        return np.sin(phase)
    cut = None if cutoff is None else np.broadcast_to(np.asarray(cutoff, dtype=float), (n,))
    top = SR * 0.45 if cut is None else min(SR * 0.45, 4 * float(cut.max()))
    out = np.zeros(n)
    previous, current = np.zeros(n), np.sin(phase)
    twice_cos = 2 * np.cos(phase)
    k = 1
    while k * f * (1 + vibrato) < top:
        if shape == 'saw' or k % 2:
            amp = 1 / k
            if cut is not None:
                amp = amp / np.sqrt(1 + ((k * f / cut) ** 2) ** order)
            out += amp * current
        previous, current = current, twice_cos * current - previous  # (sin((k+1)x) sans recalculer de sinus)
        k += 1
    return out


# --- La batterie et les bruits -------------------------------------------------------------------------------------

def kick():
    n = at(0.45)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(52 + 150 * np.exp(-t * 32)) / SR) * np.exp(-t * 9)
    click = spectral(rng.standard_normal(n), 1500, 9000) * np.exp(-t * 500)
    return edges(np.tanh(2.2 * (body + 0.45 * click)) / np.tanh(2.2))


def clap():
    n = at(0.4)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), 1000, 9000)
    noise /= np.std(noise)
    env = sum(np.where(t >= start, np.exp(-(t - start) * 140), 0) for start in (0.0, 0.011, 0.022))
    env = env + 0.8 * np.clip((t - 0.022) / 0.008, 0, 1) * np.exp(-np.maximum(t - 0.03, 0) * 15)
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28)
    return edges(0.35 * noise * env + 0.45 * body)


def snare():
    n = at(0.25)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), 1800, 9000)
    noise /= np.std(noise)
    return edges(0.5 * noise * np.exp(-t * 26) + 0.5 * np.sin(2 * np.pi * 205 * t) * np.exp(-t * 40))


def hat(decay=55, seconds=0.09):
    """Charleston fermé (ou à moitié ouvert : decay plus petit, plus long)."""
    n = at(seconds)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), 7000, 16000)
    return edges(0.5 * noise / np.std(noise) * np.exp(-t * decay))


def crash(seconds=2.4):
    n = at(seconds)
    t = np.arange(n) / SR
    env = np.exp(-t * 2.3) * np.minimum(t / 0.002, 1)
    sides = []
    for _ in range(2):
        noise = spectral(rng.standard_normal(n), 3500, 14000)
        sides.append(edges(0.4 * noise / np.std(noise) * env, 0.001, 0.05))
    return np.array(sides)


def tom(base):
    n = at(0.5)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(base * (1 + 0.6 * np.exp(-t * 22))) / SR) * np.exp(-t * 8)
    skin = spectral(rng.standard_normal(n), 200, 3000)
    skin = 0.15 * skin / np.std(skin) * np.exp(-t * 40)
    return edges(np.tanh(1.5 * (body + skin)))


def boom():
    """L'impact grave d'une grande entrée (le début, le boss, la fin)."""
    n = at(2.0)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(32 + 60 * np.exp(-t * 7)) / SR) * np.exp(-t * 2.0)
    rumble = spectral(rng.standard_normal(n), 30, 400)
    rumble = 0.35 * rumble / np.std(rumble) * np.exp(-t * 4)
    return edges(np.tanh(1.8 * (body + rumble)) / np.tanh(1.8), 0.002, 0.2)


def whoosh(before=0.42, after=0.3, direction=-1):
    """Le souffle d'un changement de plan, le plus fort au changement (`before` s après le début du son) ; il passe
    d'un côté à l'autre (direction -1 : de la droite vers la gauche, comme l'image qui glisse)."""
    n = at(before + after)
    t = np.arange(n) / SR - before
    noise = rng.standard_normal(n)
    sweep = np.where(t < 0, 1 + t / before, 1 - 0.7 * t / after)  # (du grave à l'aigu, puis redescend un peu)
    centers = np.geomspace(300, 7000, 9)
    out = np.zeros(n)
    for index, center in enumerate(centers):
        band = spectral(noise, center / 1.4, center * 1.4)
        out += band / np.std(band) * np.exp(-((sweep - index / (len(centers) - 1)) / 0.17) ** 2)
    out *= np.where(t < 0, np.exp(t * 8), np.exp(-t * 11))
    out = edges(out / np.max(np.abs(out)), 0.002, 0.03)
    left, right = pan_gains(direction * 0.7 * np.where(t < 0, t / before, t / after))
    return np.array([out * left, out * right])


# --- Les instruments à notes ---------------------------------------------------------------------------------------

def bass(note, gate, bright=1.0, release=0.02):
    seconds = gate + release
    t = np.arange(at(seconds)) / SR
    cutoff = 180 + bright * (380 + 1300 * np.exp(-t * 22))
    sound = 0.75 * oscillator(hz(note), seconds, 'saw', cutoff=cutoff) + 0.3 * oscillator(hz(note), seconds, 'sine')
    return sound * adsr(gate, release, attack=0.003, decay=0.09, sustain=0.7)


def supersaw(notes, seconds, cutoff, spread=11):
    """Un accord de dents de scie un peu désaccordées (3 voix par note, étalées à gauche et à droite)."""
    n = at(seconds)
    left, right = np.zeros(n), np.zeros(n)
    for note in notes:
        for side, pan in ((-1, -0.6), (0, 0.0), (1, 0.6)):
            sound = oscillator(hz(note), seconds, 'saw', cutoff=cutoff, detune=side * spread,
                               offset=rng.uniform(0, 2 * np.pi))
            gain_left, gain_right = pan_gains(pan)
            left += sound * gain_left
            right += sound * gain_right
    return np.array([left, right]) / np.sqrt(len(notes) * 3)


def pad(notes, gate, release, cut_from, cut_to):
    seconds = gate + release
    t = np.arange(at(seconds)) / SR
    cutoff = cut_from * (cut_to / cut_from) ** np.clip(t / gate, 0, 1)
    return supersaw(notes, seconds, cutoff) * adsr(gate, release, attack=0.03, decay=0.5, sustain=0.85)


def stab(notes, gate, release=0.12):
    """Un coup d'accord de « cuivres » (le filtre s'ouvre puis se referme vite)."""
    seconds = gate + release
    t = np.arange(at(seconds)) / SR
    return supersaw(notes, seconds, 650 + 3600 * np.exp(-t * 10), spread=7) * \
        adsr(gate, release, attack=0.004, decay=0.18, sustain=0.55)


def lead(note, gate, release=0.07):
    seconds = gate + release
    t = np.arange(at(seconds)) / SR
    cutoff = 4200 + 3000 * np.exp(-t * 14)
    vibrato = 0.005 if gate >= 0.5 else 0.0
    body = 0.65 * oscillator(hz(note), seconds, 'saw', cutoff=cutoff, vibrato=vibrato) + \
        0.45 * oscillator(hz(note), seconds, 'square', cutoff=cutoff, vibrato=vibrato)
    wide = [oscillator(hz(note), seconds, 'saw', cutoff=cutoff, detune=cents, vibrato=vibrato, offset=1.3)
            for cents in (-8, 8)]
    env = adsr(gate, release, attack=0.006, decay=0.15, sustain=0.8)
    return np.array([(body + 0.35 * wide[0]) * env, (body + 0.35 * wide[1]) * env])


def bell(note, seconds=0.5):
    f = hz(note)
    t = np.arange(at(seconds)) / SR
    sound = np.zeros(len(t))
    for ratio, amp, decay in ((1, 1.0, 6), (2, 0.4, 11), (3, 0.18, 17), (4.2, 0.1, 25)):
        if f * ratio < SR * 0.45:
            sound += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay)
    return edges(sound, 0.002, 0.03)


def ducking(kicks, n, depth, recover=0.1):
    """Le « pompage » : le son baisse d'un coup à chaque grosse caisse et remonte en `recover` s."""
    curve = np.ones(n)
    t = np.arange(at(0.45)) / SR
    shape = 1 - depth * np.minimum(t / 0.004, 1) * np.exp(-np.maximum(t - 0.004, 0) / recover)
    for time in kicks:
        i = at(time)
        k = min(len(shape), n - i)
        if k > 0:
            curve[i:i + k] = np.minimum(curve[i:i + k], shape[:k])
    return curve


def reverb(send, seconds=1.6, rt60=1.3):
    """Une salle : le son convolué avec un souffle qui s'éteint (un différent à gauche et à droite)."""
    t = np.arange(at(seconds)) / SR
    wet = []
    for _ in range(2):
        response = spectral(rng.standard_normal(len(t)), 200, 6000) * np.exp(-6.91 * t / rt60)
        response[:at(0.012)] = 0
        wet.append(convolve(send, response / np.sqrt(np.sum(response ** 2))))
    return np.array(wet)


# --- Le morceau -----------------------------------------------------------------------------------------------------

def compose(levels=False):
    """Le morceau entier, stéréo (2 x échantillons), LENGTH secondes, le pic à -1 dB."""
    n = at(LENGTH + TAIL)
    buses = {name: np.zeros((2, n)) for name in ('batterie', 'basse', 'accords', 'mélodie', 'clochettes', 'effets')}
    send = np.zeros(n)  # (ce qui part dans la réverbération)
    kicks = []

    def add(bus, signal, time, gain=1.0, pan=0.0, wet=0.0):
        i = at(time)
        if signal.ndim == 1:
            left, right = pan_gains(pan)
            signal = np.array([signal * left, signal * right])
        k = min(signal.shape[1], n - i)
        if k <= 0:
            return
        buses[bus][:, i:i + k] += gain * signal[:, :k]
        if wet:
            send[i:i + k] += wet * gain * signal[:, :k].mean(axis=0)

    def start_of(bar):
        return (bar - 1) * BAR

    for bar in range(1, BARS + 1):
        start = start_of(bar)
        chord = SONG[bar - 1]
        root = ROOTS[chord]
        boss = bar in (7, 8)

        # La batterie : grosse caisse à chaque temps (un seul coup à la dernière mesure), claps aux temps 2 et 4.
        for beat in range(4 if bar < BARS else 1):
            time = start + beat * BEAT
            add('batterie', kick(), time, 0.62)
            kicks.append(time)
            if bar >= 3 and beat in (1, 3):
                add('batterie', clap(), time, 0.6, wet=0.25)
                if bar >= 7:
                    add('batterie', snare(), time, 0.3, wet=0.15)
        if bar < BARS:
            for step in range(16 if boss else 8):
                time = start + step * BAR / (16 if boss else 8)
                if boss:
                    gain = (0.12, 0.18, 0.32, 0.18)[step % 4]
                elif bar <= 2:
                    gain = 0.3 if step % 2 else 0.0
                else:
                    gain = 0.36 if step % 2 else 0.15
                if gain:  # (à moitié ouvert en contretemps quand toute la batterie joue : « tss »)
                    sound = hat(20, 0.25) if bar >= 3 and not boss and step % 2 else hat()
                    add('batterie', sound, time, gain * (0.7 if sound.size > at(0.1) else 1), pan=0.3)
        if bar in (2, 6):  # roulement avant l'entrée de la mélodie et avant le boss
            for step in range(4):
                add('batterie', snare(), start + 3 * BEAT + step * BEAT / 4, 0.15 + 0.08 * step, wet=0.2)
        if bar == 8:  # roulement de 2 temps et toms qui descendent avant la victoire
            for step in range(8):
                add('batterie', snare(), start + 2 * BEAT + step * BEAT / 4, 0.12 + 0.055 * step, wet=0.2)
            for step, base in enumerate((150, 125, 105, 88)):
                add('batterie', tom(base), start + 3 * BEAT + step * BEAT / 4, 0.4, pan=-0.3 + 0.2 * step)
        if boss:
            for position in (0, 3, 6):
                add('batterie', tom(82), start + position * BEAT / 2, 0.4, wet=0.15)
        if bar in (1, 3, 5, 7, 9, 10):
            add('effets', crash(), start, 0.38 if bar == BARS else 0.3, wet=0.2)
        if bar in (1, 7, 10):
            add('effets', boom(), start, 0.85 if bar != 7 else 0.75)
        if bar in WHOOSHES:  # le changement de plan
            add('effets', whoosh(direction=WHOOSHES[bar]), start - 0.42, 0.28)

        # La basse : en contretemps dans l'intro, qui roule (3 doubles croches par temps) ensuite, en croches
        # marquées 3 + 3 + 2 pour le boss, une seule longue note à la fin.
        if bar <= 2:
            for position in (1, 3, 5, 7):
                add('basse', bass(root, 0.16, bright=0.3 + 0.2 * (bar - 1)), start + position * BEAT / 2, 0.45)
        elif boss:
            for position in range(8):
                accent = position in (0, 3, 6)
                add('basse', bass(root + (12 if position in (2, 5) else 0), 0.17, bright=1.1 if accent else 0.7),
                    start + position * BEAT / 2, 0.48 if accent else 0.34)
        elif bar < BARS:
            for beat in range(4):
                for sixteenth, (shift, gain) in enumerate(((0, 0.4), (0, 0.34), (12, 0.38)), start=1):
                    add('basse', bass(root + shift, 0.085, bright=0.8), start + beat * BEAT + sixteenth * BEAT / 4, gain)
        else:
            add('basse', bass(root, 1.0, bright=0.6, release=0.4), start, 0.6)

        # Les accords : un nappe qui s'ouvre dans l'intro, des cuivres pour le boss, l'accord final qui résonne.
        notes = CHORDS[chord]
        if bar == 1:
            add('accords', pad(notes, BAR, 0.1, 300, 800), start, 0.5, wet=0.25)
        elif bar == 2:
            add('accords', pad(notes, BAR, 0.3, 800, 2600), start, 0.5, wet=0.25)
        elif boss:
            add('accords', pad(notes, BAR, 0.25, 1800, 1800), start, 0.25, wet=0.25)
            for position, length in ((0, 3), (3, 3), (6, 2)):
                add('accords', stab(notes, length * BEAT / 2 * 0.85), start + position * BEAT / 2, 0.55, wet=0.25)
        elif bar < BARS:
            add('accords', pad(notes, BAR, 0.25, 3200, 3200), start, 0.32, wet=0.25)
        else:
            add('accords', pad(notes, 1.0, 0.9, 2800, 1200), start, 0.5, wet=0.3)
            add('accords', stab(notes, 0.6, release=0.9), start, 0.6, wet=0.3)
        if bar == 9:
            add('accords', stab(notes, 0.3), VICTORY, 0.55, wet=0.3)

        # La mélodie (doublée à l'octave en dessous à partir du boss), avec un écho gauche / droite.
        for position, length, note in MELODY.get(bar, ()):
            time = start + position * BEAT / 2
            release = 0.6 if bar == BARS else 0.07
            for octave, gain in ((0, 0.33), (-12, 0.13)) if bar >= 7 else ((0, 0.33),):
                sound = lead(note + octave, length * BEAT / 2 * 0.92, release)
                add('mélodie', sound, time, gain, wet=0.3)
                for delay, echo, side in ((0.3, 0.3, 0.6), (0.6, 0.18, -0.6), (0.9, 0.1, 0.6)):
                    add('mélodie', sound.mean(axis=0), time + delay, gain * echo, pan=side)

        # Les clochettes : un arpège en doubles croches (plus fort au fil de l'intro).
        if bar in ARPS:
            chord_notes = ARPS[bar]
            for step in range(16):
                gain = (0.12 + 0.08 * (bar - 1 + step / 16) / 2) if bar <= 2 else 0.2
                add('clochettes', bell(chord_notes[step % 4]), start + step * BEAT / 4, gain,
                    pan=0.35 if step % 2 else -0.35, wet=0.5)
    for index, note in enumerate((81, 84, 88, 93, 96, 100)):  # le scintillement de l'œuf
        add('clochettes', bell(note, 1.2), SPARKLE + index * 0.035, 0.16, pan=-0.5 + index * 0.2, wet=0.9)

    buses['accords'] *= ducking(kicks, n, 0.55)
    buses['clochettes'] *= ducking(kicks, n, 0.3)
    buses['basse'] *= ducking(kicks, n, 0.35)
    wet = reverb(send)
    if levels:
        for name, bus in buses.items():
            print(f'  {name:<10} {20 * np.log10(np.sqrt(np.mean(bus[:, :at(LENGTH)] ** 2)) + 1e-12):6.1f} dB')
        print(f'  {"réverb":<10} {20 * np.log10(np.sqrt(np.mean((0.3 * wet[:, :at(LENGTH)]) ** 2)) + 1e-12):6.1f} dB')
    mix = sum(buses.values()) + 0.3 * wet
    mix = np.array([spectral(side, 28) for side in mix])[:, :at(LENGTH)]  # (rien sous 28 Hz)
    fade = at(0.6)
    mix[:, -fade:] *= np.linspace(1, 0, fade) ** 2
    return mix / np.max(np.abs(mix)) * 10 ** (-1 / 20)


def write(path, levels=False):
    """Fabrique le morceau et l'écrit en WAV (48 kHz, stéréo, 16 bits)."""
    mix = compose(levels)
    data = (np.clip(mix.T, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(data.tobytes())
    return mix.shape[1] / SR


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--sortie', required=True)
    parser.add_argument('--niveaux', action='store_true')
    args = parser.parse_args()
    print(f'Musique : {args.sortie} ({write(args.sortie, args.niveaux):.2f} s)')
