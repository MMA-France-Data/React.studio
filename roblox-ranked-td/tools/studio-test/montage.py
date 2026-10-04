# MONTAGE de la vidéo de la page du jeu (video.ps1) : coupe les plans filmés par OBS (out/video/r1.mp4 à r5.mp4), les
# enchaîne avec des transitions et pose dessus UNE musique du jeu, d'un seul morceau du début à la fin. Demandes du
# propriétaire (04/10/2026) : « des rushs de 3/4 s, une vidéo de 16 s », puis « fais des transitions, enlève le volume
# du jeu » (le son filmé sautait à chaque changement de plan), puis « une musique du jeu » (pas une musique fabriquée).
#   python tools/studio-test/montage.py --plans tools/studio-test/out/video --sortie A-PUBLIER
#   (--musique fichier : une autre musique, jouée depuis son premier son)
# Sorties : video-16s.mp4 (le jeu seul) et video-16s-titres.mp4 (avec un titre en anglais sur chaque plan), en
# 1920 x 1080, 60 images/s, H.264 + AAC (Roblox : 30 s au plus, .mp4, textes et son en anglais), copiées dans
# --sortie ; apercu.png : le milieu de chaque plan et le milieu de chaque transition, pour vérifier.
# ffmpeg : celui du PATH, sinon celui de l'application Medal (déjà installée sur le PC du propriétaire), ou --ffmpeg.
# Il faut numpy (pour trouver les attaques de la musique).
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np

# Les plans gardés, dans l'ordre : (fichier, titre de la version « titres », hauteur du titre (part de l'image),
# moment fort, transition vers le plan suivant).
#   hauteur : sous le bandeau du haut de l'écran d'un niveau quand il est à l'image (r2) ;
#   moment fort : None = le plan est gardé à partir de START (l'action dure tout le plan) ; sinon le panneau qui
#   apparaît (la tour spéciale, la victoire : le plus grand changement d'image du fichier) arrive ce temps-là après le
#   début du plan ;
#   transition : un effet du filtre xfade de ffmpeg : l'image suivante pousse la précédente (slideleft : vers la
#   gauche, slideup : vers le haut) ou un flash blanc (fadewhite, pour l'arrivée du boss). (essayés et écartés :
#   zoomin, qui zoome sur le chemin vide et fait une image toute bleue ; circleopen, un fondu flou ; circlecrop, un
#   écran noir.)
# (l'œuf, r4, entre les deux plans du glacier : r2 le niveau 38 en entier, r3 son boss)
PLANS = [
    ('r1', 'DEFEND YOUR CASTLE', 0.075, None, 'slideleft'),
    ('r2', 'BUILD AND UPGRADE', 0.16, None, 'slideup'),
    ('r4', 'HATCH SPECIAL TOWERS', 0.075, 0.4, 'fadewhite'),
    ('r3', 'BEAT EPIC BOSSES', 0.075, None, 'slideleft'),
    ('r5', '', 0.075, 0.4, None),
]
# Chaque plan dure environ 3,2 s : chaque changement de plan est déplacé (0,2 s au plus) sur l'attaque la plus forte
# de la musique à côté (une note, un coup), pour que les transitions tombent en rythme. Une transition dure 0,4 s, à
# cheval sur le changement (0,2 s avant, 0,2 s après) : chaque plan est coupé 0,2 s plus long de chaque côté où il a
# une transition, et la vidéo dure 16 s pile.
PLAN = 3.2
FADE = 0.4
SNAP = 0.2
START = 1.0               # s : début d'un plan sans moment fort (OBS vient de démarrer avant)
LOUDNESS = -16            # LUFS : le niveau habituel des vidéos
MUSIC_FADE = 1.2          # s : la musique s'éteint à la fin (elle est coupée au milieu du morceau)
# La musique : « Courtly Dances » (APM Music, sous licence Roblox), Sounds.MusicHub1 (« Map : danses de la cour »),
# la plus rythmée des 4 musiques du jeu (les autres commencent doucement). Studio garde les sons qu'il a joués dans
# %TEMP%\Roblox\sounds, sous des noms au hasard : elle y est trouvée par sa durée, puis copiée dans --plans.
GAME_MUSIC = ('Courtly Dances', 151.80)
MUSIC_COPY = 'musique-jeu.ogg'
WIDTH, HEIGHT, FPS = 1920, 1080, 60
FONT = 'C\\:/Windows/Fonts/ariblk.ttf'  # Arial Black (échappement des « : » pour ffmpeg)


def find_ffmpeg(given):
    if given:
        return given
    found = shutil.which('ffmpeg')
    if found:
        return found
    local = os.environ.get('LOCALAPPDATA', '')
    candidates = sorted(glob.glob(os.path.join(local, 'Medal', 'recorder-*', 'ffmpeg*.exe')), key=os.path.getmtime, reverse=True)
    if candidates:
        return candidates[0]
    sys.exit("ffmpeg introuvable (ni dans le PATH, ni dans l'application Medal) : donne son chemin avec --ffmpeg")


def probe(ffmpeg, path):
    """(durée en s, a du son ?) d'une vidéo, lus dans ce qu'affiche ffmpeg -i."""
    result = subprocess.run([ffmpeg, '-hide_banner', '-i', path], capture_output=True, text=True, encoding='utf-8', errors='replace')
    text = result.stderr
    match = re.search(r'Duration: (\d+):(\d+):(\d+\.\d+)', text)
    duration = int(match.group(1)) * 3600 + int(match.group(2)) * 60 + float(match.group(3)) if match else 0.0
    return duration, re.search(r'Stream #\d+:\d+.*: Audio:', text) is not None


def biggest_change(ffmpeg, path, after):
    """Moment (s) du plus grand changement d'image après `after` s (score de scène de ffmpeg), ou None."""
    command = [ffmpeg, '-hide_banner', '-nostats', '-i', path, '-an', '-vf', "select='gte(scene,0)',metadata=print:file=-", '-f', 'null', '-']
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
    best, best_time, time = -1.0, None, None
    for line in result.stdout.splitlines():
        match = re.search(r'pts_time:([\d.]+)', line)
        if match:
            time = float(match.group(1))
            continue
        match = re.search(r'lavfi\.scene_score=([\d.]+)', line)
        if match and time is not None and time >= after:
            score = float(match.group(1))
            if score > best:
                best, best_time = score, time
    return best_time


def find_music(ffmpeg, given, folder):
    """Le fichier de la musique : --musique, sinon la musique du jeu dans le cache de Studio (copiée dans `folder`),
    sinon la copie d'une fois précédente."""
    if given:
        return given
    copy = os.path.join(folder, MUSIC_COPY)
    cache = os.path.join(os.environ.get('TEMP', ''), 'Roblox', 'sounds')
    for path in sorted(glob.glob(os.path.join(cache, '*')), key=os.path.getmtime, reverse=True):
        if os.path.getsize(path) > 500_000 and abs(probe(ffmpeg, path)[0] - GAME_MUSIC[1]) < 0.15:
            shutil.copyfile(path, copy)
            return copy
    if os.path.isfile(copy):
        return copy
    sys.exit(f'Musique du jeu « {GAME_MUSIC[0]} » introuvable dans {cache} : ouvre le jeu dans Studio et laisse jouer '
             'la musique (ou « Map : danses de la cour » dans le panneau SONS (Studio)), puis relance ; ou donne un '
             'fichier avec --musique')


def decode(ffmpeg, path, start, length, rate=22050):
    """Le son (mono, `rate` Hz) de `length` s à partir de `start` s, en nombres de -1 à 1."""
    pcm = subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-ss', f'{start:.3f}', '-t', f'{length:.3f}',
                          '-i', path, '-ac', '1', '-ar', str(rate), '-f', 's16le', '-'], capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2') / 32768.0


def attacks(sound, rate=22050):
    """Les attaques (notes, coups) : (moments en s, force), la force = la montée soudaine du spectre."""
    hop, size = 128, 1024
    frames = np.lib.stride_tricks.sliding_window_view(sound, size)[::hop] * np.hanning(size)
    spectrum = np.log1p(10 * np.abs(np.fft.rfft(frames, axis=1)))
    flux = np.maximum(np.diff(spectrum, axis=0), 0).sum(axis=1)
    flux = np.maximum(flux - np.convolve(flux, np.ones(64) / 64, mode='same'), 0)
    return (np.arange(1, len(flux) + 1) * hop + size / 2) / rate, flux


def loudness(ffmpeg, path, start, length):
    """Le niveau sonore d'un morceau de fichier (première passe du filtre loudnorm : ce qu'il affiche en JSON)."""
    command = [ffmpeg, '-hide_banner', '-nostats', '-ss', f'{start:.3f}', '-t', f'{length:.3f}', '-i', path, '-af',
               f'loudnorm=I={LOUDNESS}:TP=-1.5:LRA=11:print_format=json', '-f', 'null', '-']
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
    match = re.search(r'\{[^{}]*"input_i"[^{}]*\}', result.stderr)
    if not match:
        sys.exit('Mesure du son ratée :\n' + result.stderr[-2000:])
    return json.loads(match.group(0))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plans', required=True)
    parser.add_argument('--sortie', required=True)
    parser.add_argument('--musique')
    parser.add_argument('--ffmpeg')
    args = parser.parse_args()
    ffmpeg = find_ffmpeg(args.ffmpeg)
    print('ffmpeg :', ffmpeg)
    total = len(PLANS) * PLAN

    # La musique part de son premier son ; les changements de plan vont sur ses attaques.
    music = find_music(ffmpeg, args.musique, args.plans)
    head = decode(ffmpeg, music, 0, 5)
    loud = np.nonzero(np.abs(head) > 0.01)[0]
    music_start = max(0.0, loud[0] / 22050 - 0.02) if len(loud) else 0.0
    times, strength = attacks(decode(ffmpeg, music, music_start, total))
    cuts = [0.0]
    for index in range(1, len(PLANS)):
        target = index * PLAN
        near = np.abs(times - target) <= SNAP
        cut = float(times[near][np.argmax(strength[near])]) if near.any() and strength[near].max() > 0 else target
        cuts.append(round(cut * FPS) / FPS)
    cuts.append(total)
    print(f'Musique : {music} (depuis {music_start:.2f} s) ; changements de plan à ' +
          ', '.join(f'{cut:.2f}' for cut in cuts[1:-1]) + ' s')

    # Les morceaux coupés : (début dans le fichier, durée), avec les 0,2 s de plus pour les transitions.
    inputs, pieces = [], []
    last = len(PLANS) - 1
    for index, (name, title, height, lead, transition) in enumerate(PLANS):
        path = os.path.join(args.plans, name + '.mp4')
        if not os.path.isfile(path):
            sys.exit(f'Plan manquant : {path} (relance le tournage : video.ps1)')
        duration, _ = probe(ffmpeg, path)
        before = FADE / 2 if index > 0 else 0.0
        length = before + cuts[index + 1] - cuts[index] + (FADE / 2 if index < last else 0.0)
        start = START
        if lead is not None:
            change = biggest_change(ffmpeg, path, 0.6)
            start = (change - lead - before) if change is not None else START
        if start < 0 or start + length > duration:
            print(f'  (attention : {name} est trop court, le panneau ne tombe pas au bon moment)')
            start = max(0.0, min(start, duration - length))
        inputs.append(path)
        pieces.append((start, length))
        print(f'  {name} : {duration:.2f} s filmées, gardé de {start:.2f} à {start + length:.2f} s '
              f'(à l\'écran de {cuts[index]:.2f} à {cuts[index + 1]:.2f} s)')

    # Graphe ffmpeg : chaque plan coupé, mis à 1920 x 1080 et 60 images/s ; les plans enchaînés par xfade (le
    # milieu de chaque transition sur le changement de plan) ; un fondu au début et à la fin.
    parts = []
    for index, (start, length) in enumerate(pieces):
        parts.append(f'[{index}:v]trim=start={start:.3f}:duration={length:.3f},setpts=PTS-STARTPTS,'
                     f'scale={WIDTH}:{HEIGHT}:flags=lanczos,fps={FPS},format=yuv420p,setsar=1[v{index}]')
    previous = 'v0'
    for index in range(1, len(pieces)):
        parts.append(f'[{previous}][v{index}]xfade=transition={PLANS[index - 1][4]}:duration={FADE:.3f}:'
                     f'offset={cuts[index] - FADE / 2:.3f}[x{index}]')
        previous = f'x{index}'
    parts.append(f'[{previous}]fade=t=in:st=0:d=0.2,fade=t=out:st={total - 0.3:.3f}:d=0.3[clean]')

    # Le son : seulement la musique (le son filmé n'est pas utilisé), remise au niveau habituel des vidéos (-16 LUFS)
    # sans la déformer (2 passes de loudnorm : mesure, puis gain fixe), un limiteur par sécurité (aucun pic au-dessus
    # de -1,5 dB), et elle s'éteint à la fin.
    level = loudness(ffmpeg, music, music_start, total)
    parts.append(f'[{len(inputs)}:a]atrim=start={music_start:.3f}:duration={total:.3f},asetpts=PTS-STARTPTS,'
                 f'loudnorm=I={LOUDNESS}:TP=-1.5:LRA=11:measured_I={level["input_i"]}:measured_TP={level["input_tp"]}:'
                 f'measured_LRA={level["input_lra"]}:measured_thresh={level["input_thresh"]}:'
                 f'offset={level["target_offset"]}:linear=true,aresample=48000,alimiter=limit=0.84:level=false,'
                 f'afade=t=out:st={total - MUSIC_FADE:.3f}:d={MUSIC_FADE:.3f}[aout]')

    # Les titres : ils apparaissent sur le changement de plan (en fondu) et s'effacent avant la transition suivante.
    titles = []
    for index, (name, title, height, lead, transition) in enumerate(PLANS):
        if title:
            begin = cuts[index] + (0.1 if index == 0 else 0.0)
            end = cuts[index + 1] - FADE / 2 - 0.02
            titles.append(f"drawtext=fontfile='{FONT}':text='{title}':fontsize=84:fontcolor=white:borderw=7:"
                          f"bordercolor=black:x=(w-text_w)/2:y=h*{height}:enable='between(t,{begin:.2f},{end:.2f})':"
                          f"alpha='min(1,(t-{begin:.2f})/0.12)*min(1,({end:.2f}-t)/0.12)'")
    graph = ';'.join(parts)
    graph_titles = graph + ';[clean]' + ','.join(titles) + '[titled]'

    os.makedirs(args.sortie, exist_ok=True)
    encode = ['-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-r', str(FPS),
              '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', '-t', f'{total:.3f}']
    outputs = []
    for suffix, video_graph, label in (('', graph, '[clean]'), ('-titres', graph_titles, '[titled]')):
        target = os.path.join(args.plans, f'video-16s{suffix}.mp4')
        command = [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y']
        for path in inputs:
            command += ['-an', '-i', path]
        command += ['-vn', '-i', music, '-filter_complex', video_graph, '-map', label, '-map', '[aout]'] + encode + [target]
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
        if result.returncode != 0:
            sys.exit('Montage raté :\n' + result.stderr[-3000:])
        duration, audio = probe(ffmpeg, target)
        size = os.path.getsize(target) / 1024 / 1024
        copy = os.path.join(args.sortie, os.path.basename(target))
        shutil.copyfile(target, copy)
        outputs.append(target)
        print(f'Vidéo : {copy} ({duration:.2f} s, {size:.1f} Mo, {"avec" if audio else "SANS"} son)')
    final = loudness(ffmpeg, outputs[0], 0, total)
    print(f'Son de la vidéo : {float(final["input_i"]):.1f} LUFS, pic {float(final["input_tp"]):.1f} dB')

    # Aperçu (version « titres ») : le milieu de chaque plan et, entre deux, le milieu de la transition.
    try:
        from PIL import Image
        moments = []
        for index in range(len(PLANS)):
            moments.append((cuts[index] + cuts[index + 1]) / 2)
            if index < last:
                moments.append(cuts[index + 1])
        thumbs = []
        for index, moment in enumerate(moments):
            frame = os.path.join(args.plans, f'apercu_{index + 1}.png')
            subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-ss', f'{moment:.2f}', '-i', outputs[1],
                            '-frames:v', '1', '-vf', 'scale=640:360', frame], check=True)
            thumbs.append(Image.open(frame))
        sheet = Image.new('RGB', (640 * 3, 360 * 3), (20, 20, 30))
        for index, thumb in enumerate(thumbs):
            sheet.paste(thumb, ((index % 3) * 640, (index // 3) * 360))
        sheet.save(os.path.join(args.plans, 'apercu.png'))
        print('Aperçu :', os.path.join(args.plans, 'apercu.png'))
    except Exception as error:  # (l'aperçu n'est qu'une aide)
        print('Aperçu pas fait :', error)


if __name__ == '__main__':
    main()
