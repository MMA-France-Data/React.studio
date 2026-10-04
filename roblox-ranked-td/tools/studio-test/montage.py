# MONTAGE de la vidéo de la page du jeu (video.ps1) : coupe les plans filmés par OBS (out/video/r1.mp4 à r5.mp4) et
# les colle en une vidéo de 16 s pile (demande du propriétaire, 04/10/2026 : « des rushs de 3/4 s, une vidéo de 16 s »).
#   python tools/studio-test/montage.py --plans tools/studio-test/out/video --sortie A-PUBLIER
# Sorties : video-16s.mp4 (le jeu seul) et video-16s-titres.mp4 (avec un titre en anglais sur chaque plan), en
# 1920 x 1080, 60 images/s, H.264 + AAC (Roblox : 30 s au plus, .mp4, textes et son en anglais), copiées dans
# --sortie ; apercu.png : une image de chaque plan, pour vérifier.
# ffmpeg : celui du PATH, sinon celui de l'application Medal (déjà installée sur le PC du propriétaire), ou --ffmpeg.
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

# Les plans gardés, dans l'ordre : (fichier, durée en s, titre de la version « titres », hauteur du titre (part de
# l'image), moment fort).
#   hauteur : sous le bandeau du haut de l'écran d'un niveau quand il est à l'image (r2) ;
#   moment fort : None = le plan est gardé à partir de START (l'action dure tout le plan) ; sinon le plan commence
#   LEAD s avant le plus grand changement d'image du fichier (le panneau qui apparaît : la tour spéciale, la victoire).
# (l'œuf, r4, entre les deux plans du glacier : r2 le niveau 38 en entier, r3 son boss)
PLANS = [
    ('r1', 3.5, 'DEFEND YOUR CASTLE', 0.075, None),
    ('r2', 3.0, 'BUILD AND UPGRADE', 0.16, None),
    ('r4', 3.0, 'HATCH SPECIAL TOWERS', 0.075, 0.5),
    ('r3', 3.0, 'BEAT EPIC BOSSES', 0.075, None),
    ('r5', 3.5, '', 0.075, 0.45),
]
START = 1.0  # s : début d'un plan sans moment fort (OBS vient de démarrer avant)
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plans', required=True)
    parser.add_argument('--sortie', required=True)
    parser.add_argument('--ffmpeg')
    args = parser.parse_args()
    ffmpeg = find_ffmpeg(args.ffmpeg)
    print('ffmpeg :', ffmpeg)

    inputs, cuts = [], []
    total = 0.0
    for name, length, title, height, lead in PLANS:
        path = os.path.join(args.plans, name + '.mp4')
        if not os.path.isfile(path):
            sys.exit(f'Plan manquant : {path} (relance le tournage : video.ps1)')
        duration, audio = probe(ffmpeg, path)
        if duration < length:
            sys.exit(f'Plan trop court : {path} ({duration:.2f} s pour {length} s)')
        start = START
        if lead is not None:
            change = biggest_change(ffmpeg, path, 0.6)
            start = (change - lead) if change is not None else START
        start = max(0.0, min(start, duration - length))
        inputs.append(path)
        cuts.append((start, length, audio, (title, height), total))
        print(f'  {name} : {duration:.2f} s filmées, gardé de {start:.2f} à {start + length:.2f} s{"" if audio else " (sans son)"}')
        total += length

    # Graphe ffmpeg : chaque plan coupé, mis à 1920 x 1080 et 60 images/s, son coupé net (petits fondus contre les
    # clics) ; puis les plans collés, un fondu au début et à la fin.
    parts, labels = [], []
    for index, (start, length, audio, _, _) in enumerate(cuts):
        parts.append(f'[{index}:v]trim=start={start:.3f}:duration={length:.3f},setpts=PTS-STARTPTS,'
                     f'scale={WIDTH}:{HEIGHT}:flags=lanczos,fps={FPS},format=yuv420p,setsar=1[v{index}]')
        source = f'[{index}:a]atrim=start={start:.3f}:duration={length:.3f},asetpts=PTS-STARTPTS' if audio \
            else f'anullsrc=r=48000:cl=stereo,atrim=duration={length:.3f}'
        parts.append(f'{source},aresample=48000,aformat=channel_layouts=stereo,'
                     f'afade=t=in:st=0:d=0.03,afade=t=out:st={length - 0.05:.3f}:d=0.05[a{index}]')
        labels.append(f'[v{index}][a{index}]')
    parts.append(''.join(labels) + f'concat=n={len(cuts)}:v=1:a=1[vc][ac]')
    parts.append(f'[vc]fade=t=in:st=0:d=0.2,fade=t=out:st={total - 0.3:.3f}:d=0.3[clean]')
    # (le son de Studio est faible : remis au niveau habituel des vidéos, -16 LUFS)
    # (puis un limiteur : aucun pic au-dessus de -1,5 dB, pas de grésillement)
    parts.append(f'[ac]loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,alimiter=limit=0.84:level=false,'
                 f'afade=t=in:st=0:d=0.15,afade=t=out:st={total - 0.4:.3f}:d=0.4[aout]')
    titles = []
    for start, length, audio, (title, height), at in cuts:
        if title:
            titles.append(f"drawtext=fontfile='{FONT}':text='{title}':fontsize=84:fontcolor=white:borderw=7:"
                          f"bordercolor=black:x=(w-text_w)/2:y=h*{height}:enable='between(t,{at + 0.1:.2f},{at + length - 0.1:.2f})'")
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
            command += ['-i', path]
        command += ['-filter_complex', video_graph, '-map', label, '-map', '[aout]'] + encode + [target]
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
        if result.returncode != 0:
            sys.exit('Montage raté :\n' + result.stderr[-3000:])
        duration, audio = probe(ffmpeg, target)
        size = os.path.getsize(target) / 1024 / 1024
        copy = os.path.join(args.sortie, os.path.basename(target))
        shutil.copyfile(target, copy)
        outputs.append(target)
        print(f'Vidéo : {copy} ({duration:.2f} s, {size:.1f} Mo, {"avec" if audio else "SANS"} son)')

    # Aperçu : une image au milieu de chaque plan (version « titres »), côte à côte.
    try:
        from PIL import Image
        thumbs = []
        for index, (_, length, _, _, at) in enumerate(cuts):
            frame = os.path.join(args.plans, f'apercu_{index + 1}.png')
            subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-ss', f'{at + length / 2:.2f}', '-i', outputs[1],
                            '-frames:v', '1', '-vf', 'scale=640:360', frame], check=True)
            thumbs.append(Image.open(frame))
        sheet = Image.new('RGB', (640 * 3, 360 * 2), (20, 20, 30))
        for index, thumb in enumerate(thumbs):
            sheet.paste(thumb, ((index % 3) * 640, (index // 3) * 360))
        sheet.save(os.path.join(args.plans, 'apercu.png'))
        print('Aperçu :', os.path.join(args.plans, 'apercu.png'))
    except Exception as error:  # (l'aperçu n'est qu'une aide)
        print('Aperçu pas fait :', error)


if __name__ == '__main__':
    main()
