# Les 30 cartes d'équipe (10 mondes x 2, 3, 4 joueurs) : demande du propriétaire (03/10/2026) : « chacun a son
# couloir qui se rejoint ensuite, exemple à 2 ça fait une map un peu en Y, adapté à chaque monde ». Après une
# modification : python tools/team-maps/generer.py (vérifie, dessine les aperçus, écrit src/shared/TeamMaps.luau).
# Tailles : à 2 : 120 x 64 (ou 66) ; à 3 : 128 x 76 ;
# à 4 : 136 x 88. Formes : à 2, un Y (deux couloirs depuis la gauche) ; à 3, un T (un couloir par la gauche, un par
# le haut, un par le bas) ; à 4, un peigne (les deux couloirs de gauche se rejoignent d'abord, puis ceux du haut et
# du bas). Chaque monde garde sa forme : la partie commune et la place du château suivent sa carte seule.
# Longueur visée : à peu près celle de la carte seule (Valley 204, Pass 282, Forest 308, Glacier 266, Desert 252,
# Necropolis 252, Storm 252, Obsidian 270, Goblin 272, Dragon 330), pour que la difficulté reste comparable.
from outil import Lane, Map

NAMES = {
    "Valley": "La vallée du Roi carmin",
    "Pass": "Le col des Pillards de cuivre",
    "Forest": "La forêt des Gardiens des ronces",
    "Glacier": "Le glacier de la Légion du givre",
    "Desert": "Le désert des Gardes des dunes",
    "Necropolis": "La nécropole de la Légion des os",
    "Storm": "La citadelle de la Garde de la tempête",
    "Obsidian": "Le volcan des Chevaliers d'obsidienne",
    "Goblin": "Les marais de la Horde gobeline",
    "Dragon": "Le repaire de la Couvée du dragon",
}

SOLO = {"Valley": 204, "Pass": 282, "Forest": 308, "Glacier": 266, "Desert": 252, "Necropolis": 252, "Storm": 252,
        "Obsidian": 270, "Goblin": 272, "Dragon": 330}


def Y(world, lane, trunk, note, size=(120, 64)):
    return Map(f"{world}_2", NAMES[world], size[0], size[1], [lane, lane.mirrored()], {"trunk": trunk}, note)


def T(world, top, middle, trunk, note, size=(128, 76)):
    return Map(f"{world}_3", NAMES[world], size[0], size[1], [top, middle, top.mirrored()], {"trunk": trunk}, note)


def comb(world, left, top, mid, trunk, note, size=(136, 88)):
    return Map(f"{world}_4", NAMES[world], size[0], size[1], [left, top, top.mirrored(), left.mirrored()], {"mid": mid, "trunk": trunk}, note)


# Couloirs qui reviennent dans plusieurs mondes.
def t_columns():  # à 3, par le haut : trois colonnes, jusqu'au point de rencontre (12, 0)
    return Lane((-16, -38), "D24 R14 U19 R14 D33", ["trunk"])


def t_middle(meet_x):  # à 3, par la gauche : une dent, puis tout droit jusqu'à (meet_x, 0)
    return Lane((-64, 0), f"R14 U14 R14 D14 R{meet_x + 36}", ["trunk"])


def t_edge():  # à 3, par le haut : le long du bord, jusqu'à (-10, 0)
    return Lane((-58, -38), "D10 R48 D28", ["trunk"])


def c_left():  # à 4, par la gauche : un coude, jusqu'à (-28, 0)
    return Lane((-68, -28), "R12 D14 R28 D14", ["mid", "trunk"])


def c_columns():  # à 4, par le haut : trois colonnes, jusqu'à (14, 0)
    return Lane((-14, -44), "D30 R14 U19 R14 D33", ["trunk"])


def c_edge_left():  # à 4, par la gauche : un escalier, jusqu'à (-34, 0)
    return Lane((-68, -30), "R20 D16 R14 D14", ["mid", "trunk"])


def c_edge_top():  # à 4, par le haut : un crochet, jusqu'à (2, 0)
    return Lane((-20, -44), "D14 R40 D16 L18 D14", ["trunk"])


def build():
    maps = []

    # 1. LA VALLÉE : créneaux, le château au milieu à droite.
    maps.append(Y("Valley", Lane((-60, -24), "R26 D16 R16 U16 R16 D24", ["trunk"]), ((-2, 0), "R14 U14 R16 D28 R16 U14 R6"),
                  "Deux couloirs en créneaux (en haut et en bas) qui se rejoignent au milieu, puis les créneaux du château."))
    maps.append(T("Valley", t_columns(), t_middle(12), ((12, 0), "R14 U18 R14 D36 R14 U18"),
                  "Un couloir par la gauche, un par le haut, un par le bas : ils se rejoignent au milieu, puis les créneaux."))
    maps.append(comb("Valley", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U16 R14 D32 R14 U16"),
                     "Les deux couloirs de gauche se rejoignent d'abord ; ceux du haut et du bas les rejoignent plus loin."))

    # 2. LE COL : longs couloirs et épingles ; la partie commune fait le tour et revient vers le centre.
    maps.append(Y("Pass", Lane((-60, -28), "R52 D14 L36 D14", ["trunk"]), ((-44, 0), "R92 U14 L28"),
                  "Chaque couloir longe le bord puis fait une épingle ; la partie commune traverse tout le terrain et revient\nvers le centre.",
                  size=(120, 66)))
    maps.append(T("Pass", t_edge(), t_middle(-10), ((-10, 0), "R24 D20 R40 U40 L26 D14"),
                  "Les couloirs du haut et du bas longent le bord ; la partie commune fait le tour de la droite et revient\nvers le centre."))
    maps.append(comb("Pass", c_edge_left(), c_edge_top(), ((-34, 0), "R36"), ((2, 0), "R32 U30 R26 D44 L12"),
                     "Longs couloirs ; la partie commune fait le tour de la droite et revient vers le centre."))

    # 3. LA FORÊT : des S, le château dans le coin en bas à droite.
    maps.append(Y("Forest", Lane((-60, -28), "R44 D14 L22 D14", ["trunk"]), ((-38, 0), "R50 D22 R14 U44 R28 D44"),
                  "Deux couloirs en S, puis des S jusqu'au château, dans le coin en bas à droite.", size=(120, 66)))
    maps.append(T("Forest", Lane((-52, -38), "D10 R42 D28", ["trunk"]), t_middle(-10), ((-10, 0), "R26 D26 R20 U52 R18 D52"),
                  "Trois couloirs qui se rejoignent, puis de grands S jusqu'au château, en bas à droite."))
    maps.append(comb("Forest", c_edge_left(), c_edge_top(), ((-34, 0), "R36"), ((2, 0), "R32 U30 R26 D64"),
                     "Quatre couloirs, puis un grand S jusqu'au château, en bas à droite."))

    # 4. LE GLACIER : passages verticaux serrés, le château au milieu à droite.
    maps.append(Y("Glacier", Lane((-60, -28), "R10 D14 R14 U14 R14 D14 R14 D14", ["trunk"]), ((-8, 0), "R14 U22 R14 D44 R14 U44 R14 D22"),
                  "Chaque couloir fait des passages verticaux serrés ; la partie commune aussi, jusqu'au château.", size=(120, 66)))
    maps.append(T("Glacier", Lane((-20, -38), "D24 R14 U19 R14 D33", ["trunk"]), Lane((-64, 0), "R14 U14 R14 D14 R44", ["trunk"]),
                  ((8, 0), "R14 U22 R14 D44 R14 U22"),
                  "Passages verticaux serrés partout, jusqu'au château, au milieu à droite."))
    maps.append(comb("Glacier", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U22 R14 D44 R14 U22"),
                     "Passages verticaux serrés, jusqu'au château, au milieu à droite."))

    # 5. LE DÉSERT : longs couloirs droits ; à 2, le château revient près des entrées ; à 3 et 4, il est en bas.
    maps.append(Y("Desert", Lane((-60, -28), "R100 D28", ["trunk"]), ((40, 0), "L20 U14 L26 D28 L26"),
                  "Deux longs couloirs droits jusqu'au bout du terrain ; la partie commune revient par le milieu (un crochet)\njusqu'au château, près des entrées.", size=(120, 66)))
    maps.append(T("Desert", t_edge(), t_middle(-10), ((-10, 0), "R64 D28 L20 U14 L20 D14"),
                  "Longs couloirs droits ; la partie commune va au bout du terrain et revient avec un crochet jusqu'au château,\nen bas."))
    maps.append(comb("Desert", c_edge_left(), c_edge_top(), ((-34, 0), "R36"), ((2, 0), "R56 D34 L20"),
                     "Longs couloirs ; la partie commune va au bout du terrain et revient au château, en bas."))

    # 6. LA NÉCROPOLE : une couronne autour du château, au centre (à 2) ou à droite (à 3 et 4).
    maps.append(Y("Necropolis", Lane((-60, -28), "R14 D14 R14 D14", ["trunk"]), ((-32, 0), "R14 D28 R44 U14 R14 U28 L14 U14 L26 D24"),
                  "Chaque couloir descend deux marches ; la partie commune fait le tour d'une couronne et plonge vers le\nchâteau, au centre.",
                  size=(120, 66)))
    maps.append(T("Necropolis", t_columns(), t_middle(12), ((12, 0), "R14 U22 R30 D44 L16 U14"),
                  "Trois couloirs qui se rejoignent ; la partie commune tourne autour du château, au milieu d'une couronne."))
    maps.append(comb("Necropolis", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U26 R32 D52 L16 U16"),
                     "Quatre couloirs ; la partie commune tourne autour du château, au milieu d'une couronne."))

    # 7. LA CITADELLE DE LA TEMPÊTE : des dents profondes, puis un grand crochet jusqu'au château, en bas à droite.
    maps.append(Y("Storm", Lane((-60, -24), "R12 D17 R14 U17 R14 D17 R14 U17 R14 D24", ["trunk"]), ((8, 0), "R14 U22 R30 D44"),
                  "Deux couloirs à dents profondes, puis un grand crochet jusqu'au château, en bas à droite."))
    maps.append(T("Storm", t_columns(), t_middle(12), ((12, 0), "R14 U22 R30 D50"),
                  "Trois couloirs qui se rejoignent, puis un grand crochet jusqu'au château, en bas à droite."))
    maps.append(comb("Storm", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U26 R30 D60"),
                     "Quatre couloirs, puis un grand crochet jusqu'au château, en bas à droite."))

    # 8. LE VOLCAN : grands passages, un long couloir en haut, puis le château en bas.
    maps.append(Y("Obsidian", Lane((-60, -26), "R14 D19 R16 U19 R28 D26", ["trunk"]), ((-2, 0), "R14 U22 R40 D30 L22 D14"),
                  "Deux couloirs à grands passages ; la partie commune longe le haut puis redescend au château, en bas."))
    maps.append(T("Obsidian", t_columns(), t_middle(12), ((12, 0), "R14 U22 R30 D30 L14 D20"),
                  "Trois couloirs ; la partie commune longe le haut puis redescend au château, en bas."))
    maps.append(comb("Obsidian", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U26 R32 D34 L16 D26"),
                     "Quatre couloirs ; la partie commune longe le haut puis redescend au château, en bas."))

    # 9. LES MARAIS : passages verticaux à 16 studs l'un de l'autre ; à 2, on entre par le haut et par le bas.
    maps.append(Y("Goblin", Lane((-52, -33), "D19 R14 U14 R14 D28", ["trunk"]), ((-24, 0), "R14 U22 R16 D44 R16 U44 R16 D22"),
                  "On entre par le haut et par le bas ; les deux couloirs se rejoignent, puis serpentent jusqu'au château.",
                  size=(120, 66)))
    maps.append(T("Goblin", Lane((-18, -38), "D24 R16 U19 R16 D33", ["trunk"]), Lane((-64, 0), "R14 U14 R14 D14 R50", ["trunk"]),
                  ((14, 0), "R14 U24 R14 D48 R14 U24"),
                  "Un couloir entre au milieu du bord gauche, les autres par le haut et le bas ; ils serpentent jusqu'au château."))
    maps.append(comb("Goblin", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R16 U26 R16 D52 R14 U26"),
                     "Quatre couloirs ; ils serpentent jusqu'au château."))

    # 10. LE REPAIRE DU DRAGON : la spirale. À 2, chaque couloir fait la moitié du grand tour, la partie commune fait
    # le petit tour ; à 3 et 4, la partie commune s'enroule autour du château.
    maps.append(Y("Dragon", Lane((-60, -28), "R112 D28", ["trunk"]), ((52, 0), "L14 U14 L86 D28 R68"),
                  "Chaque couloir fait la moitié du grand tour (l'un en haut, l'autre en bas) ; la partie commune fait le petit\ntour jusqu'au château, presque au centre.", size=(120, 66)))
    maps.append(T("Dragon", t_columns(), t_middle(12), ((12, 0), "R14 U28 R32 D56 L18 U38"),
                  "Trois couloirs se rejoignent, puis la partie commune s'enroule autour du château."))
    maps.append(comb("Dragon", c_left(), c_columns(), ((-28, 0), "R42"), ((14, 0), "R14 U30 R32 D60 L18 U40"),
                     "Quatre couloirs se rejoignent, puis la partie commune s'enroule autour du château."))
    return maps
