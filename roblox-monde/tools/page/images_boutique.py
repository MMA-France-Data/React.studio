# LES IMAGES DES ARTICLES DE LA BOUTIQUE EN ROBUX (les 4 potions et les 2 pass à vie), à importer dans le tableau de
# bord de Roblox avec chaque article. Mêmes fioles que dans le jeu (src/client/Draw.luau).
#   python tools/page/images_boutique.py "C:\...\dossier de sortie"
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
K = 3  # dessiné 3 fois plus grand puis réduit : des bords lisses
DARK = (20, 20, 30, 255)
WHITE = (255, 255, 255, 255)
FONT = "C:/Windows/Fonts/ariblk.ttf"
U = SIZE * K


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def backdrop(color):
    """Fond violet nuit, plus clair au milieu, avec des rayons de la couleur de l'article."""
    image = Image.new("RGBA", (U, U), (0, 0, 0, 255))
    pixels = ImageDraw.Draw(image)
    night, glow = (26, 20, 60), mix(color, (40, 30, 90), 0.45)
    for step in range(60, 0, -1):
        radius = U * 0.75 * step / 60
        pixels.ellipse([U / 2 - radius, U / 2 - radius, U / 2 + radius, U / 2 + radius], fill=mix(glow, night, step / 60))
    rays = Image.new("RGBA", (U, U), (0, 0, 0, 0))
    pen = ImageDraw.Draw(rays)
    for index in range(12):
        angle, spread, far = index * math.pi / 6 + 0.26, math.pi / 30, U
        pen.polygon(
            [(U / 2, U / 2), (U / 2 + math.cos(angle - spread) * far, U / 2 + math.sin(angle - spread) * far), (U / 2 + math.cos(angle + spread) * far, U / 2 + math.sin(angle + spread) * far)],
            fill=color[:3] + (46,),
        )
    image.alpha_composite(rays)
    return image


def shaded(size, color, top, bottom):
    """Un rectangle de cette couleur, clair en haut et sombre en bas."""
    width, height = int(size[0]), int(size[1])
    image = Image.new("RGBA", (width, height))
    pen = ImageDraw.Draw(image)
    for y in range(height):
        k = top + (bottom - top) * y / max(1, height - 1)
        pen.line([(0, y), (width, y)], fill=tuple(int(c * k) for c in color[:3]) + (255,))
    return image


def paste_shape(image, box, color, top, bottom, radius=None, ellipse=False, outline=0.0):
    """Colle une forme ombrée (rectangle arrondi ou rond), avec son contour sombre."""
    x0, y0, x1, y1 = [int(v) for v in box]
    width, height = x1 - x0, y1 - y0
    mask = Image.new("L", (width, height), 0)
    pen = ImageDraw.Draw(mask)
    if ellipse:
        pen.ellipse([0, 0, width - 1, height - 1], fill=255)
    else:
        pen.rounded_rectangle([0, 0, width - 1, height - 1], radius=radius or 0, fill=255)
    if outline:
        line = int(outline)
        draw = ImageDraw.Draw(image)
        if ellipse:
            draw.ellipse([x0 - line, y0 - line, x1 + line, y1 + line], fill=DARK)
        else:
            draw.rounded_rectangle([x0 - line, y0 - line, x1 + line, y1 + line], radius=(radius or 0) + line, fill=DARK)
    image.paste(shaded((width, height), color, top, bottom), (x0, y0), mask)


def text(image, value, center, height, fill=WHITE, stroke=0.11):
    pen = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT, int(height))
    pen.text(center, value, font=font, fill=fill, anchor="mm", stroke_width=int(height * stroke), stroke_fill=DARK)


def flask(image, color, glyph, cx, cy, size):
    """La fiole du jeu : bouchon, goulot de verre, panse ronde, reflet, bulles et sa lettre. `size` : sa hauteur."""
    unit = size / 110
    x0, y0 = cx - 55 * unit, cy - 55 * unit

    def box(x, y, w, h):
        return [x0 + x * unit, y0 + y * unit, x0 + (x + w) * unit, y0 + (y + h) * unit]

    line = 3.2 * unit
    paste_shape(image, box(38, 2, 34, 18), (160, 105, 55), 1, 0.7, radius=5 * unit, outline=line)
    paste_shape(image, box(40, 16, 30, 34), (205, 235, 255), 1, 0.85, radius=6 * unit, outline=line)
    paste_shape(image, box(13, 26, 84, 84), color, 1.0, 0.55, ellipse=True, outline=line)
    shine = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pen = ImageDraw.Draw(shine)
    pen.rounded_rectangle(box(26, 40, 10, 34), radius=5 * unit, fill=(255, 255, 255, 140))
    pen.ellipse(box(28, 80, 8, 8), fill=(255, 255, 255, 115))
    pen.ellipse(box(66, 56, 12, 12), fill=(255, 255, 255, 76))
    pen.ellipse(box(60, 76, 7, 7), fill=(255, 255, 255, 76))
    image.alpha_composite(shine)
    if glyph:
        text(image, glyph, (x0 + 55 * unit, y0 + 70 * unit), 34 * unit if len(glyph) > 1 else 40 * unit)


def coin(image, cx, cy, size):
    gold = (255, 205, 40)
    half = size / 2
    paste_shape(image, [cx - half, cy - half, cx + half, cy + half], gold, 1, 0.72, ellipse=True, outline=size * 0.035)
    inner = half * 0.76
    paste_shape(image, [cx - inner, cy - inner, cx + inner, cy + inner], (210, 168, 33), 1, 0.9, ellipse=True)
    text(image, "$", (cx, cy), size * 0.6, fill=(255, 240, 150, 255))


def badge(image, value, cx, cy, radius, color=(255, 60, 70)):
    """Une pastille ronde (« x3 », « x2 »)."""
    paste_shape(image, [cx - radius, cy - radius, cx + radius, cy + radius], color, 1.1, 0.8, ellipse=True, outline=radius * 0.1)
    text(image, value, (cx, cy), radius * 1.0)


def banner(image, value, color):
    """Le bandeau du bas (« FOREVER », « 30 MIN »)."""
    paste_shape(image, [U * 0.10, U * 0.80, U * 0.90, U * 0.95], color, 1.15, 0.8, radius=U * 0.03, outline=U * 0.012)
    text(image, value, (U * 0.5, U * 0.872), U * 0.095)


def finish(image, path):
    image.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(path)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    green, blue, gold, red = (60, 220, 90), (70, 140, 255), (255, 200, 40), (240, 60, 70)

    image = backdrop(green)
    flask(image, green, "S", U * 0.5, U * 0.42, U * 0.66)
    banner(image, "RANK UP", (40, 170, 70))
    finish(image, os.path.join(out, "produit-Rank-Potion.png"))

    for name, color, glyph in (("Double-XP-Potions", blue, "XP"), ("Double-Coins-Potions", gold, "$"), ("Double-Damage-Potions", red, "x2")):
        image = backdrop(color)
        flask(image, color, glyph, U * 0.5, U * 0.42, U * 0.66)
        badge(image, "x3", U * 0.80, U * 0.20, U * 0.13)
        banner(image, "x2  •  30 MIN", tuple(int(c * 0.78) for c in color))
        finish(image, os.path.join(out, "produit-" + name + ".png"))

    image = backdrop(blue)
    flask(image, blue, "XP", U * 0.5, U * 0.42, U * 0.66)
    badge(image, "x2", U * 0.80, U * 0.20, U * 0.15)
    banner(image, "FOREVER", (150, 70, 220))
    finish(image, os.path.join(out, "pass-2x-XP.png"))

    image = backdrop(gold)
    coin(image, U * 0.5, U * 0.42, U * 0.56)
    badge(image, "x2", U * 0.80, U * 0.20, U * 0.15)
    banner(image, "FOREVER", (150, 70, 220))
    finish(image, os.path.join(out, "pass-2x-Coins.png"))
    print("ok", out)


if __name__ == "__main__":
    main()
