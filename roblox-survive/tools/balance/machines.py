"""Calcule le prix des niveaux de machine de SURVIVE! pour que la machine au maximum demande environ 200 heures.

    python tools/balance/machines.py          -> affiche le tableau et la ligne a coller dans Config.luau

Le principe : on se donne le parcours d'un joueur regulier (a quelle heure de jeu il atteint chaque salle), on en
deduit ce que rapportent ses familiers a chaque heure, et le prix d'un niveau de machine = une part de ce qu'il gagne
pendant le temps qu'on veut lui faire attendre ce niveau. Ce n'est qu'un premier reglage : tout se change ici.
"""
import math

LEVELS = 15  # niveaux de machine (peu de niveaux, chacun est un grand saut, comme dans les jeux du genre)
GAIN = 4.47  # points par pas : x 4,47 a chaque niveau (deux niveaux = un palier de stat, qui vaut 20 fois le precedent)
TIER2_GAIN = 7  # points par pas au niveau 4, celui du palier 2 (2 500 points en 3 minutes)

# Heure de jeu a laquelle un joueur regulier atteint chaque salle (salle 1 a 10).
ROOM_HOURS = [0, 0.3, 0.6, 1.5, 3, 5, 9, 14, 22, 40]
# Heure de jeu a laquelle il doit pouvoir s'offrir ce niveau de machine (entre deux : en ligne droite).
# Niveaux 4, 6, 8, 10, 13 : ceux qu'il faut pour les paliers de stat 2, 3, 4, 5, 6 (voir Config.POINTS) : avec
# eux, le palier demande environ 3 minutes d'entrainement ; avec la machine du palier d'avant, une heure.
LEVEL_HOURS = {1: 0, 2: 0.12, 3: 1.2, 4: 2.5, 5: 4.5, 6: 8, 7: 13, 8: 20, 9: 28, 10: 36, 11: 60, 12: 90, 13: 120, 14: 160, 15: 200}

ROOM_FACTOR = 10  # Pets.ROOM_FACTOR : les familiers valent 10 fois plus a chaque salle
MEAN_VALUE = 109  # valeur cachee moyenne d'un oeuf de la salle 1 (chances x paliers de Pets.luau)
CURATED = 2.2  # un joueur vend ses mauvais familiers : son enclos vaut environ 2,2 fois la moyenne
SHARE = 0.2  # part de ses pieces qui va dans UNE machine (trois machines, et l'enclos a agrandir)


def room_at(hours):
    room = 1
    for index, start in enumerate(ROOM_HOURS):
        if hours >= start:
            room = index + 1
    return room


def places_at(hours):
    # L'enclos : 5 places au debut, 14 vers 40 heures, 20 vers 200 heures.
    if hours <= 40:
        return 5 + 9 * hours / 40
    return min(20, 14 + 6 * (hours - 40) / 160)


def income_at(hours):
    """Pieces par seconde d'un joueur regulier a cette heure de jeu (ses familiers viennent de la salle d'avant)."""
    room = max(1, room_at(hours) - 1) if hours > 0.2 else 1
    start_pets = min(places_at(hours), 1 + hours * 20)  # les toutes premieres minutes : un seul familier, puis l'enclos se remplit
    return start_pets * MEAN_VALUE / 100 * CURATED * ROOM_FACTOR ** (room - 1)


def hour_of(level):
    keys = sorted(LEVEL_HOURS)
    for a, b in zip(keys, keys[1:]):
        if a <= level <= b:
            return LEVEL_HOURS[a] + (LEVEL_HOURS[b] - LEVEL_HOURS[a]) * (level - a) / (b - a)
    return LEVEL_HOURS[keys[-1]]


def nice(value):
    """Arrondit a deux chiffres qui comptent (1 234 567 -> 1 200 000)."""
    if value <= 0:
        return 0
    digits = int(math.floor(math.log10(value)))
    step = 10 ** max(0, digits - 1)
    return int(round(value / step) * step)


def prices():
    result = []
    previous = 0
    for level in range(2, LEVELS + 1):
        wait = (hour_of(level) - hour_of(level - 1)) * 3600
        price = income_at(hour_of(level)) * wait * SHARE
        price = max(price, previous * 1.12, 500)  # jamais moins cher que le niveau d'avant
        price = 500 if level == 2 else nice(price)  # le premier niveau : 500 pieces (le chiffre du joueur)
        result.append(price)
        previous = price
    return result


def gain(level):
    # 1, 2, 3 pour les trois premiers niveaux, puis x 4,47 par niveau a partir du niveau 4.
    return nice(max(level, TIER2_GAIN * GAIN ** (level - 4)))


if __name__ == '__main__':
    table = prices()
    total = 0
    print('niveau | prix          | cumul         | heure visee | revenu/s a cette heure | points par pas')
    for level in range(2, LEVELS + 1):
        price = table[level - 2]
        total += price
        if True:
            print('%6d | %13s | %13s | %9.1f h | %14s | %s' % (level, format(price, ','), format(total, ','), hour_of(level), format(int(income_at(hour_of(level))), ','), format(gain(level), ',')))
    print()
    print('Config.PRICES = { ' + ', '.join(str(p) for p in table) + ' }')
    print('Config.GAINS = { ' + ', '.join(str(gain(level)) for level in range(1, LEVELS + 1)) + ' }')
