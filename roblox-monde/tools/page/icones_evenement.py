# LES ICÔNES « COMPTE À REBOURS » DE LA PAGE DU JEU (demande du créateur, 09/10 : « certains jeux ont ça », un sablier
# et « 1H! » sur leur icône avant un événement). Ce n'est pas Roblox qui le fait : chaque créateur remplace lui-même
# l'icône de son jeu avant l'événement, puis remet la normale.
#   python tools/page/icones_evenement.py "C:\...\icone 1.png" "C:\...\dossier de sortie"
# Fabrique, à partir de l'icône du jeu : icone-1H.png, icone-30MIN.png et icone-NOW.png (1024 x 1024).
import math
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

SIZE = 1024
K = 3  # on dessine 3 fois plus grand puis on réduit : des bords lisses
DARK = (20, 20, 30, 255)
WHITE = (255, 255, 255, 255)
SAND = (255, 200, 40, 255)
RED = (255, 60, 70, 255)
FONT = "C:/Windows/Fonts/ariblk.ttf"


def backdrop(source: Image.Image, dim: float) -> Image.Image:
    """L'icône du jeu, un peu floue et assombrie, pour que le blanc ressorte."""
    image = source.convert("RGB").resize((SIZE * K, SIZE * K), Image.LANCZOS)
    image = image.filter(ImageFilter.GaussianBlur(4 * K))
    image = ImageEnhance.Brightness(image).enhance(dim)
    image = ImageEnhance.Color(image).enhance(0.85)
    return image.convert("RGBA")


def hourglass(draw: ImageDraw.ImageDraw, cx: float, cy: float, h: float) -> None:
    """Un sablier blanc à gros contour : deux barres, deux triangles de verre, du sable doré."""
    w = h * 0.62
    bar = h * 0.11
    line = int(h * 0.035)
    top, bottom = cy - h / 2, cy + h / 2
    neck = w * 0.07
    glass = [
        (cx - w * 0.40, top + bar), (cx + w * 0.40, top + bar),
        (cx + neck, cy), (cx + w * 0.40, bottom - bar),
        (cx - w * 0.40, bottom - bar), (cx - neck, cy),
    ]
    # Le contour sombre, puis le verre blanc.
    draw.polygon(glass, fill=WHITE, outline=DARK, width=line)
    draw.line(glass + [glass[0]], fill=DARK, width=line, joint="curve")
    # Le sable : un peu en haut, un tas en bas.
    def across(y: float) -> float:
        """La demi-largeur du verre à cette hauteur."""
        t = abs(y - cy) / (h / 2 - bar)
        return neck + (w * 0.40 - neck) * t

    inset = line * 1.1
    y1 = top + bar + (h / 2 - bar) * 0.55
    draw.polygon([(cx - across(y1) + inset, y1), (cx + across(y1) - inset, y1), (cx + neck * 0.4, cy - inset), (cx - neck * 0.4, cy - inset)], fill=SAND)
    y2 = bottom - bar - (h / 2 - bar) * 0.42
    y3 = bottom - bar - inset * 0.6
    draw.polygon([(cx, y2 - h * 0.05), (cx + across(y3) - inset, y3), (cx - across(y3) + inset, y3)], fill=SAND)
    draw.line([(cx, cy), (cx, y2)], fill=SAND, width=max(2, int(neck * 0.7)))
    # Les deux barres.
    for y in (top, bottom - bar):
        draw.rounded_rectangle([cx - w / 2, y, cx + w / 2, y + bar], radius=bar * 0.35, fill=WHITE, outline=DARK, width=line)


def bang(layer: Image.Image, cx: float, cy: float, h: float, angle: float) -> None:
    """Un point d'exclamation rouge, penché."""
    box = int(h * 1.4)
    stamp = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    pen = ImageDraw.Draw(stamp)
    font = ImageFont.truetype(FONT, int(h))
    pen.text((box / 2, box / 2), "!", font=font, fill=RED, anchor="mm", stroke_width=int(h * 0.09), stroke_fill=DARK)
    stamp = stamp.rotate(angle, resample=Image.BICUBIC)
    layer.alpha_composite(stamp, (int(cx - box / 2), int(cy - box / 2)))


def title(draw: ImageDraw.ImageDraw, text: str, cy: float, height: float, fill) -> None:
    """Le gros texte du bas, à gros contour, réduit s'il dépasse."""
    size = int(height)
    while True:
        font = ImageFont.truetype(FONT, size)
        stroke = int(size * 0.11)
        left, top, right, bottom = draw.textbbox((0, 0), text, font=font, stroke_width=stroke)
        if right - left <= SIZE * K * 0.92 or size < 40:
            break
        size -= 8
    draw.text((SIZE * K / 2, cy), text, font=font, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=DARK)


def countdown(source: Image.Image, text: str) -> Image.Image:
    image = backdrop(source, 0.34)
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    u = SIZE * K
    hourglass(draw, u * 0.5, u * 0.36, u * 0.52)
    bang(layer, u * 0.17, u * 0.24, u * 0.20, 22)
    bang(layer, u * 0.83, u * 0.24, u * 0.20, -22)
    bang(layer, u * 0.13, u * 0.47, u * 0.13, 38)
    bang(layer, u * 0.87, u * 0.47, u * 0.13, -38)
    title(ImageDraw.Draw(layer), text, u * 0.81, u * 0.30, WHITE)
    image.alpha_composite(layer)
    return image.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def live(source: Image.Image, text: str) -> Image.Image:
    """« C'est maintenant » : l'icône reste claire, des rayons dorés, le mot en jaune."""
    image = backdrop(source, 0.72)
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    u = SIZE * K
    for index in range(12):
        angle = index * math.pi / 6
        spread = math.pi / 26
        far = u * 1.2
        draw.polygon(
            [(u / 2, u / 2), (u / 2 + math.cos(angle - spread) * far, u / 2 + math.sin(angle - spread) * far), (u / 2 + math.cos(angle + spread) * far, u / 2 + math.sin(angle + spread) * far)],
            fill=(255, 230, 120, 70),
        )
    bang(layer, u * 0.15, u * 0.30, u * 0.22, 22)
    bang(layer, u * 0.85, u * 0.30, u * 0.22, -22)
    title(draw, text, u * 0.50, u * 0.40, (255, 221, 51, 255))
    image.alpha_composite(layer)
    return image.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main() -> None:
    source = Image.open(sys.argv[1])
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    countdown(source, "1H!").save(os.path.join(out, "icone-1H.png"))
    countdown(source, "30 MIN!").save(os.path.join(out, "icone-30MIN.png"))
    live(source, "NOW!").save(os.path.join(out, "icone-NOW.png"))
    print("ok", out)


if __name__ == "__main__":
    main()
