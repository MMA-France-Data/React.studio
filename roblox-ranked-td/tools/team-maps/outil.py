# Outil de conception des cartes d'ÉQUIPE (un couloir par joueur, qui se rejoignent avant le château). Les cartes
# elles-mêmes sont dans cartes.py ; generer.py les vérifie, dessine les aperçus et écrit src/shared/TeamMaps.luau.
# Une carte = des couloirs décrits « à la tortue » depuis leur entrée (R = droite, L = gauche, U = haut (-Z),
# D = bas (+Z), suivis d'une longueur ; « a » = longueur réglée par l'outil pour que tous les couloirs aient la
# même longueur), puis des morceaux communs (nommés) jusqu'au château.
# Vérifie : tronçons droits et assez longs, entrées sur un bord et tournées vers l'intérieur, couloirs de longueurs
# proches, écarts entre les chemins, château dans le terrain ; dessine un aperçu PNG ; écrit le code Luau des cartes.
import math
import os
from PIL import Image, ImageDraw, ImageFont

PATH_W = 6.0
CLEAR = 5.0          # tour <-> milieu du chemin
MIN_SEP = 14.0       # deux bouts de chemin qui ne se touchent pas : au moins ça entre leurs milieux
EDGE = 5.0           # milieu du chemin <-> bord du terrain (sauf entrée)
BASE_AHEAD = 4.0     # le château est à 4 studs après le dernier point
HERE = os.path.dirname(os.path.abspath(__file__))


def turtle(start, spec, a=0.0):
    x, z = start
    pts = [(x, z)]
    for tok in spec.split():
        d, arg = tok[0], tok[1:]
        if arg == "a":
            n = a
        elif arg.endswith("a") and arg[:-1]:
            n = float(arg[:-1]) * a
        else:
            n = float(arg)
        if d == "R":
            x += n
        elif d == "L":
            x -= n
        elif d == "U":
            z -= n
        elif d == "D":
            z += n
        else:
            raise ValueError(tok)
        if n != 0:
            pts.append((x, z))
    return pts


def mirror_spec(spec):
    out = []
    for tok in spec.split():
        d = {"U": "D", "D": "U"}.get(tok[0], tok[0])
        out.append(d + tok[1:])
    return " ".join(out)


def var_count(spec):
    k = 0.0
    for tok in spec.split():
        arg = tok[1:]
        if arg == "a":
            k += 1
        elif arg.endswith("a") and arg[:-1]:
            k += float(arg[:-1])
    return k


def length(pts):
    return sum(math.dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


class Lane:
    def __init__(self, start, spec, shared=()):
        self.start = start
        self.spec = spec
        self.shared = list(shared)  # noms des morceaux communs, dans l'ordre (le dernier mène au château)

    def mirrored(self, shared=None):
        return Lane((self.start[0], -self.start[1]), mirror_spec(self.spec), shared if shared is not None else self.shared)


class Map:
    def __init__(self, name, display, width, depth, lanes, pieces, note=""):
        self.name, self.display, self.width, self.depth = name, display, width, depth
        self.lanes = lanes
        self.pieces = pieces  # nom -> (départ, spec) : morceaux communs
        self.note = note
        self.solve()

    def piece_points(self, name):
        start, spec = self.pieces[name]
        return turtle(start, spec)

    def lane_points(self, lane, a):
        pts = turtle(lane.start, lane.spec, a)
        for name in lane.shared:
            piece = self.piece_points(name)
            if math.dist(pts[-1], piece[0]) > 1e-6:
                raise ValueError(f"{self.name} : le couloir n'arrive pas au départ du morceau {name} ({pts[-1]} au lieu de {piece[0]})")
            pts = pts + piece[1:]
        return pts

    def solve(self):
        # Couloirs avec « a » : réglés pour avoir la longueur du plus long couloir sans « a » (ou du plus long tout court).
        fixed = [length(self.lane_points(lane, 0.0)) for lane in self.lanes]
        plain = [base for lane, base in zip(self.lanes, fixed) if var_count(lane.spec) == 0]
        target = max(plain) if plain else max(fixed)
        self.values = []
        for lane, base in zip(self.lanes, fixed):
            k = var_count(lane.spec)
            self.values.append(0.0 if k == 0 else (target - base) / k)
        self.paths = [self.lane_points(lane, a) for lane, a in zip(self.lanes, self.values)]
        self.lengths = [length(pts) for pts in self.paths]
        self.total = max(self.lengths)
        self.bases = []
        for pts in self.paths:
            last, before = pts[-1], pts[-2]
            dx, dz = last[0] - before[0], last[1] - before[1]
            n = math.hypot(dx, dz)
            self.bases.append((last[0] + dx / n * BASE_AHEAD, last[1] + dz / n * BASE_AHEAD))
        self.base = self.bases[0]

    # Tronçons uniques (un tronçon commun n'est compté qu'une fois) : (a, b, couloirs qui l'empruntent)
    def segments(self):
        found = {}
        order = []
        for index, pts in enumerate(self.paths):
            for i in range(1, len(pts)):
                key = (pts[i - 1], pts[i])
                if key not in found:
                    found[key] = set()
                    order.append(key)
                found[key].add(index)
        return [(a, b, found[(a, b)]) for (a, b) in order]

    def check(self):
        problems = []
        W, D = self.width, self.depth
        for index, (pts, a) in enumerate(zip(self.paths, self.values)):
            if a < -1e-6 or (0 < a < 6):
                problems.append(f"couloir {index + 1} : détour réglé à {a:.1f} (il faut 0 ou au moins 6)")
            if math.dist(self.bases[index], self.base) > 1e-6:
                problems.append(f"couloir {index + 1} : il n'arrive pas au même château")
            for i in range(1, len(pts)):
                (x1, z1), (x2, z2) = pts[i - 1], pts[i]
                if x1 != x2 and z1 != z2:
                    problems.append(f"couloir {index + 1} : tronçon pas droit {pts[i - 1]} -> {pts[i]}")
                elif math.dist(pts[i - 1], pts[i]) < PATH_W:
                    problems.append(f"couloir {index + 1} : tronçon plus court que la largeur du chemin {pts[i - 1]} -> {pts[i]}")
            x0, z0 = pts[0]
            x1, z1 = pts[1]
            on_left = x0 == -W / 2 and x1 > x0
            on_top = z0 == -D / 2 and z1 > z0
            on_bottom = z0 == D / 2 and z1 < z0
            on_right = x0 == W / 2 and x1 < x0
            if not (on_left or on_top or on_bottom or on_right):
                problems.append(f"couloir {index + 1} : l'entrée {pts[0]} n'est pas sur un bord du terrain (vers l'intérieur)")
            for (x, z) in pts[1:]:
                if abs(x) > W / 2 - EDGE + 1e-6 or abs(z) > D / 2 - EDGE + 1e-6:
                    problems.append(f"couloir {index + 1} : point {x, z} trop près du bord")
        if max(self.lengths) > min(self.lengths) * 1.15:
            problems.append(f"couloirs trop différents : {[round(v) for v in self.lengths]}")
        bx, bz = self.base
        if abs(bx) > W / 2 - 5 or abs(bz) > D / 2 - 5:
            problems.append(f"château {self.base} trop près du bord")
        # Écarts entre bouts de chemin qui ne se touchent pas.
        segs = self.segments()
        for i in range(len(segs)):
            for j in range(i + 1, len(segs)):
                a1, b1, l1 = segs[i]
                a2, b2, l2 = segs[j]
                if {a1, b1} & {a2, b2}:
                    continue  # se touchent à un bout (virage, jonction)
                dist = seg_dist(a1, b1, a2, b2)
                if dist < MIN_SEP - 1e-6:
                    problems.append(f"chemins trop proches ({dist:.1f}) : {a1}->{b1} et {a2}->{b2}")
        # Entrées assez éloignées (portes).
        for i in range(len(self.paths)):
            for j in range(i + 1, len(self.paths)):
                if math.dist(self.paths[i][0], self.paths[j][0]) < 14:
                    problems.append("deux entrées trop proches")
        return problems

    def spots(self, count=12):
        segs = self.segments()
        samples = []
        for a, b, lanes in segs:
            n = max(1, int(math.dist(a, b) // 2))
            for k in range(n + 1):
                t = k / n
                samples.append(((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), len(lanes)))
        W, D = self.width, self.depth
        candidates = []
        x = -W / 2 + 4
        while x <= W / 2 - 4:
            z = -D / 2 + 4
            while z <= D / 2 - 4:
                p = (x, z)
                near = min(point_seg(p, a, b) for a, b, _ in segs)
                if near >= CLEAR + 1 and math.dist(p, self.base) >= 9:
                    score = sum(w for s, w in samples if math.dist(s, p) <= 19)
                    candidates.append((score, p))
                z += 2
            x += 2
        candidates.sort(key=lambda c: -c[0])
        chosen = []
        for score, p in candidates:
            if all(math.dist(p, q) >= 9 for q in chosen):
                chosen.append(p)
            if len(chosen) >= count:
                break
        return chosen


def point_seg(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    if dx == 0 and dz == 0:
        return math.dist(p, a)
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.dist(p, (ax + dx * t, az + dz * t))


def seg_dist(a1, b1, a2, b2):
    if segments_cross(a1, b1, a2, b2):
        return 0.0
    return min(point_seg(a1, a2, b2), point_seg(b1, a2, b2), point_seg(a2, a1, b1), point_seg(b2, a1, b1))


def segments_cross(a1, b1, a2, b2):
    def orient(p, q, r):
        v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        return 0 if abs(v) < 1e-9 else (1 if v > 0 else -1)
    o1, o2, o3, o4 = orient(a1, b1, a2), orient(a1, b1, b2), orient(a2, b2, a1), orient(a2, b2, b1)
    return o1 != o2 and o3 != o4 and 0 not in (o1, o2, o3, o4)


LANE_COLORS = [(46, 160, 110), (90, 120, 220), (220, 120, 60), (200, 80, 160)]


def render(maps, filename, scale=4):
    pad = 24
    widths = [int(m.width * scale) + pad * 2 for m in maps]
    height = max(int(m.depth * scale) for m in maps) + pad * 2 + 24
    img = Image.new("RGB", (sum(widths), height), (245, 245, 240))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    x0 = 0
    for m, w in zip(maps, widths):
        ox, oz = x0 + pad + m.width * scale / 2, pad + 24 + m.depth * scale / 2

        def P(p):
            return (ox + p[0] * scale, oz + p[1] * scale)

        draw.text((x0 + pad, 4), f"{m.name} : " + " / ".join(str(round(v)) for v in m.lengths), fill=(30, 30, 30), font=font)
        draw.rectangle([P((-m.width / 2, -m.depth / 2)), P((m.width / 2, m.depth / 2))], fill=(150, 185, 120), outline=(90, 110, 80))
        for (sx, sz) in m.spots():
            r = CLEAR * scale * 0.5
            cx, cz = P((sx, sz))
            draw.ellipse([cx - r, cz - r, cx + r, cz + r], outline=(255, 255, 255))
        for a, b, lanes in m.segments():
            color = (120, 112, 100) if len(lanes) > 1 else LANE_COLORS[min(lanes)]
            draw.line([P(a), P(b)], fill=color, width=int(PATH_W * scale))
            for p in (a, b):
                cx, cz = P(p)
                r = PATH_W * scale / 2
                draw.rectangle([cx - r, cz - r, cx + r, cz + r], fill=color)
        bx, bz = P(m.base)
        r = 3.5 * scale
        draw.rectangle([bx - r, bz - r, bx + r, bz + r], fill=(110, 80, 60))
        for index, pts in enumerate(m.paths):
            cx, cz = P(pts[0])
            draw.text((cx + 4, cz - 22), f"J{index + 1}", fill=(0, 0, 0), font=font)
        x0 += w
    img.save(os.path.join(HERE, filename))


def luau_vector(p):
    x, z = p
    fx = int(x) if float(x).is_integer() else round(x, 2)
    fz = int(z) if float(z).is_integer() else round(z, 2)
    return f"Vector3.new({fx}, 0, {fz})"


def luau_map(m):
    lines = [f"\t{m.name} = {{"]
    if m.note:
        for row in m.note.split("\n"):
            lines.append(f"\t\t-- {row}")
    lines.append(f"\t\t-- Couloirs de {' / '.join(str(round(v)) for v in m.lengths)} studs (de l'entrée au château).")
    lines.append(f"\t\tdisplayName = \"{m.display}\",")
    lines.append(f"\t\twidth = {m.width},")
    lines.append(f"\t\tdepth = {m.depth},")
    lines.append("\t\tlanes = {")
    for pts in m.paths:
        lines.append("\t\t\t{ " + ", ".join(luau_vector(p) for p in pts) + " },")
    lines.append("\t\t},")
    lines.append(f"\t\tbase = {luau_vector(m.base)},")
    lines.append("\t\tspots = { " + ", ".join(luau_vector(p) for p in m.spots()) + " },")
    lines.append("\t},")
    return "\n".join(lines)
