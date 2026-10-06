"""Calcule le prix des niveaux de machine de SURVIVE!.

    python tools/balance/machines.py          -> affiche le tableau et les deux lignes a coller dans Config.luau

LA REGLE (demandes du joueur, 06/10/2026) :
  - les 10 premieres salles se font en 2 a 3 heures de jeu ;
  - ensuite, chaque nouvelle salle demande UNE JOURNEE DE JEU (5 heures) : il sort une salle par jour, le joueur ne
    doit pas le rattraper ;
  - aucun joueur ne doit avoir "fini" le jeu : la machine au maximum est a plus de 200 heures.
  - "je veux pas qu'il y ait forcement une amelioration de tapis a chaque niveau, par ex la salle 4 et 5 peuvent
    etre speed 10 k et saut 15 k" : une machine sert pour PLUSIEURS salles.
  -> UN NIVEAU DE MACHINE TOUTES LES 3 SALLES. Le niveau 2 se paie avec les familiers de la salle 2 (il sert pour
     les salles 3, 4, 5), le niveau 3 avec ceux de la salle 5 (salles 6, 7, 8), le niveau 4 avec ceux de la salle 8,
     etc. Chaque niveau donne 20 fois plus de points par pas (1, 20, 400, 8 000...) : avec lui, ce que demandent
     ses trois salles s'entraine en quelques minutes (10 000 points au niveau 2 = 4 minutes).
     20 niveaux : le dernier se paie avec les familiers de la salle 56, vers 230 heures de jeu. Sans nouvelle
     salle, le revenu ne monte plus : il reste toujours quelque chose a viser.

Le prix d'un niveau = ce que le joueur gagne pendant le temps qu'on veut lui faire attendre ce niveau, fois la part
de ses pieces qui va dans une machine. Ce n'est qu'un calcul : rien n'a ete joue. Tout se regle ici.
"""
import math

LEVELS = 20  # niveaux de machine
ROOMS_PER_LEVEL = 3  # une machine sert pour trois salles
FIRST_ROOMS = 10  # les salles du debut, rapides
# Heure de jeu a laquelle un joueur regulier atteint chacune des 10 premieres salles (la salle 10 a 2 h 30).
FIRST_HOURS = [0, 0.06, 0.15, 0.3, 0.5, 0.75, 1.05, 1.4, 1.9, 2.5]
DAY = 5  # heures de jeu d'une "journee" : le temps que doit demander chaque salle apres la 10e

ROOM_FACTOR = 10  # Pets.ROOM_FACTOR : les familiers valent 10 fois plus a chaque salle, jusqu'a la salle 10
LATE_FACTOR = 2  # Pets.LATE_FACTOR : puis 2 fois plus a chaque salle
# Valeur cachee d'un oeuf ordinaire de la salle 1, en centiemes de piece par seconde (Pets.VALUE) : la moyenne des
# quatre premiers rangs (commun a epique, 96 % des oeufs). Les legendaires et super rares sont des coups de chance :
# on ne regle pas les prix dessus. (.45 x 350 + .30 x 1000 + .14 x 3750 + .07 x 18000) / .96
MEAN_VALUE = 2300
CURATED = 2.2  # un joueur vend ses mauvais familiers : son enclos vaut environ 2,2 fois la moyenne
SHARE = 0.2  # part de ses pieces qui va dans UNE machine (trois machines, et l'enclos a agrandir)

# Points par pas : x 20 a chaque niveau de machine (demande du joueur : "passer de 1 a +20"). C'est aussi l'ecart
# entre deux paliers de stat (Config.POINTS).
GAIN = 20


def room_hour(room):
    """Heure de jeu a laquelle on atteint cette salle."""
    if room <= FIRST_ROOMS:
        return FIRST_HOURS[room - 1]
    return FIRST_HOURS[-1] + (room - FIRST_ROOMS) * DAY


def room_factor(room):
    return ROOM_FACTOR ** (min(room, FIRST_ROOMS) - 1) * LATE_FACTOR ** max(0, room - FIRST_ROOMS)


def places_at(hours):
    # L'enclos : 5 places au debut, 10 vers 2 h 30, 20 vers 200 heures.
    if hours <= 2.5:
        return 5 + 5 * hours / 2.5
    return min(20, 10 + 10 * (hours - 2.5) / 197.5)


def income_with(room, hours):
    """Pieces par seconde d'un joueur regulier dont les familiers viennent de cette salle."""
    pets = min(places_at(hours), 1 + hours * 60)  # les toutes premieres minutes : un seul familier
    return pets * MEAN_VALUE / 100 * CURATED * room_factor(room)


def nice(value):
    """Arrondit a deux chiffres qui comptent (1 234 567 -> 1 200 000)."""
    if value <= 0:
        return 0
    digits = int(math.floor(math.log10(value)))
    step = 10 ** max(0, digits - 1)
    return int(round(value / step) * step)


def room_of(level):
    """La salle dont les familiers paient ce niveau de machine : 2, 5, 8, 11..."""
    return ROOMS_PER_LEVEL * level - 4


def prices():
    """Prix pour passer au niveau 2, 3..."""
    result = []
    previous = 0
    for level in range(2, LEVELS + 1):
        room = room_of(level)
        start, end = room_hour(room), room_hour(room + 1)
        price = income_with(room, (start + end) / 2) * (end - start) * 3600 * SHARE
        price = nice(max(price, previous * 1.5))
        result.append(price)
        previous = price
    return result


def gain(level):
    return GAIN ** (level - 1)


SUFFIXES = [(1e27, 'Oc'), (1e24, 'Sp'), (1e21, 'Sx'), (1e18, 'Qi'), (1e15, 'Qa'), (1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')]


def short(value):
    for size, name in SUFFIXES:
        if value >= size:
            return '%.3g%s' % (value / size, name)
    return '%d' % value


PEN_FREE, PEN_MAX = 5, 20  # places de l'enclos au depart, et au plus (Pets.SPOTS_FREE, Pets.SPOTS_MAX)
PEN_SHARE = 0.3  # part de ses pieces que le joueur met dans son enclos


def room_at(hours):
    """La salle ou en est un joueur regulier a cette heure de jeu."""
    room = 1
    while room < 400 and room_hour(room + 1) <= hours:
        room += 1
    return room


def pen_hour(place):
    """Heure de jeu a laquelle on vise l'achat de cette place : les 5 premieres pendant les 10 premieres salles
    (la 6e des la salle 2), puis une toutes les 20 heures jusqu'a la 20e vers 200 heures."""
    if place <= 10:
        # 6e place des la salle 2 (5 minutes de jeu), puis de plus en plus espace jusqu'a la 10e a 2 h 30.
        return [0, 0.08, 0.25, 0.6, 1.2, 2.5][place - PEN_FREE]
    return 2.5 + (place - 10) * (200 - 2.5) / (PEN_MAX - 10)


def pen_prices():
    """Prix de la 6e place, de la 7e... Meme principe que les machines."""
    result = []
    previous = 0
    for place in range(PEN_FREE + 1, PEN_MAX + 1):
        start, end = pen_hour(place - 1), pen_hour(place)
        middle = (start + end) / 2
        price = income_with(max(1, room_at(middle) - 1), middle) * (end - start) * 3600 * PEN_SHARE
        price = nice(max(price, previous * 1.5))
        result.append(price)
        previous = price
    return result


if __name__ == '__main__':
    table = prices()
    print('niveau | prix     | points par pas | se paie avec la salle | vers')
    for level in range(2, LEVELS + 1):
        room = room_of(level)
        print('%6d | %8s | %14s | %21d | %.1f h' % (level, short(table[level - 2]), short(gain(level)), room, room_hour(room)))
    print()
    print('Config.PRICES = { ' + ', '.join(str(p) for p in table) + ' }')
    print('Config.GAINS = { ' + ', '.join(str(gain(level)) for level in range(1, LEVELS + 1)) + ' }')
    print('Pets.SPOT_PRICES = { ' + ', '.join(str(p) for p in pen_prices()) + ' }')
    print('places de l\'enclos : ' + ', '.join('%d = %s' % (PEN_FREE + 1 + i, short(p)) for i, p in enumerate(pen_prices())))
