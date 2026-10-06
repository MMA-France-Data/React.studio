"""Calcule le prix des niveaux de machine de SURVIVE!.

    python tools/balance/machines.py          -> affiche le tableau et les deux lignes a coller dans Config.luau

LA REGLE (demandes du joueur, 06/10/2026) :
  - les 10 premieres salles se font en 2 a 3 heures de jeu ;
  - ensuite, chaque nouvelle salle demande UNE JOURNEE DE JEU (5 heures) : il sort une salle par jour, le joueur ne
    doit pas le rattraper ;
  - aucun joueur ne doit avoir "fini" le jeu : la machine au maximum est a plus de 200 heures.
  -> UN NIVEAU DE MACHINE PAR SALLE. Le niveau N se paie avec les familiers de la salle N. Niveaux 1 a 10 :
     les 10 premieres salles (2 h 30). Niveaux 11 a 50 : une journee de jeu chacun (le niveau 50 vers 200 heures),
     en supposant qu'une nouvelle salle sort a chaque fois. Sans nouvelle salle, le revenu ne monte plus et chaque
     niveau demande deux fois plus de temps que le precedent : il reste toujours quelque chose a viser.

Le prix d'un niveau = ce que le joueur gagne pendant le temps qu'on veut lui faire attendre ce niveau, fois la part
de ses pieces qui va dans une machine. Ce n'est qu'un calcul : rien n'a ete joue. Tout se regle ici.
"""
import math

LEVELS = 50  # niveaux de machine (un par salle ; les salles 11 a 50 n'existent pas encore)
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

# Points par pas : la machine niveau 2 passe de +1 a +20 (demande du joueur : "passer de 1 a +20", pour que la
# salle 3 demande d'ameliorer ses trois machines et environ 5 minutes d'entrainement). Ensuite x 4,47 par niveau
# jusqu'au niveau 10 (deux niveaux = x 20, comme les paliers de Config.POINTS), puis x 1,5.
LEVEL2_GAIN = 20
EARLY_GAIN = 4.47
LATE_GAIN = 1.5


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


def prices():
    """Prix pour passer au niveau 2, 3... Le niveau N se paie pendant qu'on fait la salle N - 1."""
    result = []
    previous = 0
    for level in range(2, LEVELS + 1):
        # Le niveau N se paie avec les familiers de la salle N, pendant qu'on prepare la salle N + 1 (le joueur :
        # "monte encore le cout des machines, a la salle 3 faut faire des sous deja" : la machine niveau 2 demande
        # un enclos de la salle 2, pas de la salle 1).
        start, end = room_hour(level), room_hour(level + 1)
        price = income_with(level, (start + end) / 2) * (end - start) * 3600 * SHARE
        price = max(price, previous * 1.5, 500)  # jamais moins d'une fois et demie le niveau d'avant
        price = nice(price)
        result.append(price)
        previous = price
    return result


def gain(level):
    if level <= 1:
        return 1
    if level <= FIRST_ROOMS:
        return nice(LEVEL2_GAIN * EARLY_GAIN ** (level - 2))
    return nice(gain(FIRST_ROOMS) * LATE_GAIN ** (level - FIRST_ROOMS))


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
    print('niveau | prix     | heure visee | revenu/s     | points par pas | sans nouvelle salle apres la 10')
    stuck = 0
    for level in range(2, LEVELS + 1):
        price = table[level - 2]
        hour = room_hour(level)
        income = income_with(level - 1, (room_hour(level - 1) + hour) / 2)
        # Sans nouvelle salle : le revenu reste celui de la salle 10.
        late = ''
        if level > FIRST_ROOMS:
            stuck += price / (income_with(FIRST_ROOMS, 2.5 + stuck) * SHARE) / 3600
            late = '%.0f h de plus' % stuck
        if level <= 16 or level % 10 == 0:
            print('%6d | %8s | %9.2f h | %12s | %12s | %s' % (level, short(price), hour, short(income), short(gain(level)), late))
    print()
    print('Config.PRICES = { ' + ', '.join(str(p) for p in table) + ' }')
    print('Config.GAINS = { ' + ', '.join(str(gain(level)) for level in range(1, LEVELS + 1)) + ' }')
    print('Pets.SPOT_PRICES = { ' + ', '.join(str(p) for p in pen_prices()) + ' }')
    print('places de l\'enclos : ' + ', '.join('%d = %s' % (PEN_FREE + 1 + i, short(p)) for i, p in enumerate(pen_prices())))
