# Cartes d'ÉQUIPE : vérifie les 30 cartes de cartes.py, dessine un aperçu par monde (tools/team-maps/apercus) et
# écrit src/shared/TeamMaps.luau (lu par Shared/Levels.luau). Depuis le dossier roblox-ranked-td :
#   python tools/team-maps/generer.py
# (Python 3 et Pillow : pip install pillow). Rien n'est écrit si une carte a un problème.
import os
import sys
from PIL import Image, ImageDraw, ImageFont
from outil import render, luau_map
from cartes import build, SOLO, NAMES

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(REPO, "src", "shared", "TeamMaps.luau")

HEADER = """-- CARTES D'ÉQUIPE (« JOUER EN ÉQUIPE », Shared/Levels.luau). Demande du propriétaire (03/10/2026) : « chacun a
-- son couloir qui se rejoint ensuite, exemple à 2 ça fait une map un peu en Y, adapté à chaque monde ».
-- Une carte par territoire et par nombre de joueurs : « Valley_2 », « Valley_3 », « Valley_4 »... Chaque joueur a SON
-- couloir (lanes[n], de son entrée au château : le joueur n de la partie défend le couloir n) ; les couloirs se
-- rejoignent ensuite (mêmes points = même chemin) et finissent au même château. Le flot de monstres est partagé
-- entre les couloirs, chacun son tour (Levels.buildQueue). Mêmes règles que les cartes seules : tronçons droits,
-- entrées sur un bord, tours posées où on veut ; spots = bons endroits (joueur simulé, essais).
-- FICHIER ÉCRIT PAR tools/team-maps/generer.py (les cartes sont dans tools/team-maps/cartes.py) : ne pas le
-- modifier à la main, il serait écrasé.
return {
"""


def overview(worlds):
    # Les dix aperçus sur une seule image (deux colonnes), pour tout voir d'un coup : apercus/toutes-les-cartes.png.
    folder = os.path.join(HERE, "apercus")
    images = [Image.open(os.path.join(folder, f"{world}.png")).convert("RGB") for world in worlds]
    width, height, title = max(i.width for i in images), max(i.height for i in images), 34
    sheet = Image.new("RGB", (width * 2, (height + title) * ((len(images) + 1) // 2)), (245, 245, 240))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arialbd.ttf", 24)
    except OSError:
        font = ImageFont.load_default()
    for index, (image, world) in enumerate(zip(images, worlds)):
        x, y = (index % 2) * width, (index // 2) * (height + title)
        draw.text((x + 24, y + 6), f"{index + 1}. {NAMES[world]}", fill=(20, 20, 20), font=font)
        sheet.paste(image, (x, y + title))
    sheet = sheet.resize((2000, int(sheet.height * 2000 / sheet.width)), Image.LANCZOS)
    sheet.save(os.path.join(folder, "toutes-les-cartes.png"))


def main():
    maps = build()
    bad = 0
    worlds = []
    for m in maps:
        world = m.name.split("_")[0]
        if world not in worlds:
            worlds.append(world)
        problems = m.check()
        ratio = m.total / SOLO[world]
        print(f"{m.name:14s} {m.width}x{m.depth}  couloirs {[round(v) for v in m.lengths]}  (carte seule : {SOLO[world]}, x{ratio:.2f})")
        for p in problems:
            bad += 1
            print("   !", p)
    os.makedirs(os.path.join(HERE, "apercus"), exist_ok=True)
    for world in worlds:
        render([m for m in maps if m.name.startswith(world + "_")], os.path.join("apercus", f"{world}.png"))
    overview(worlds)
    if bad:
        print(f"{bad} problème(s) : TeamMaps.luau n'est pas écrit.")
        sys.exit(1)
    text = HEADER + "\n".join(luau_map(m) for m in maps) + "\n}\n"
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"{len(maps)} cartes écrites dans {os.path.relpath(OUT, REPO)} ; aperçus dans tools/team-maps/apercus.")


if __name__ == "__main__":
    main()
