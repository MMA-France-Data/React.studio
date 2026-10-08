# Simulation grossière des mondes 1 ET 2 : combien de temps pour battre chaque boss ?
# Même joueur « malin » que monde1.py : il combat toujours le camp le plus haut qu'il peut gagner (dans le monde le
# plus loin qu'il a ouvert), garde ses trois meilleurs familiers, achète l'épée suivante dès qu'il a les pièces.
# Les chiffres doivent être les mêmes que Config.luau et Pets.luau.
#   python tools/balance/mondes.py        : les durées sur 40 parties
#   python tools/balance/mondes.py -v     : le détail d'une partie
import random, statistics, sys

WORLDS = 3
HP = [40, 300, 700, 1500, 3200, 9000]
DMG = [3, 15, 30, 60, 125, 400]
FIRST = (100, 7)                      # le premier camp des mondes suivants (pas l'exception du canard)
COINS = [3, 8, 20, 50, 130, 200]
XP = [4, 26, 60, 125, 260, 600]
EGG = [0.20, 0.05, 0.05, 0.05, 0.05, 0.05]
FIGHT_DMG = [5, 10, 20, 40, 85, 600]
FIGHT_HP = [45, 90, 180, 360, 760, 5400]
RANK_XP = [1, 10, 30, 70, 110, 80]
GRADE_ODDS = [70, 25, 4.6, 0.4]
SWORDS = [(3, 0), (8, 30), (25, 1500), (78, 20000), (250, 200000), (1160, 2500000), (5400, 10000000), (25000, 25000000)]
NEED = 60
EARLY = 0.3   # Pets.EARLY_XP : les cinq premiers niveaux d un familier demandent cette part de l XP normale
ZONE, COIN_ZONE, XP_ZONE = 100, 100, 10   # d'un monde au suivant : monstres et familiers, pièces, XP
# D un monde au suivant, en plus : l XP des familiers est LONG_XP fois plus longue et les oeufs LONG_EGG fois plus rares
# (Pets.LONG_XP, Config.LONG_EGG) : chaque monde dure plus longtemps que le precedent.
LONG_XP, LONG_EGG = [1, 10, 13], [1, 1, 1]   # par monde (Pets.LONG_XP, Config.LONG_EGG)
WALK = 4.0
INCOME = [0.15, 0.3, 0.75, 2, 5, 12]  # pieces par seconde d un familier moyen de chaque rang, au monde 1 (Pets.INCOME)

LONG_PRICE = 1.25   # Config.LONG_PRICE : les epees d un monde coutent 100 x LONG_PRICE fois celles du monde d avant
# (Cinq epees au monde 1, trois au monde 2 ; au-dela : les trois memes marches, 100 fois plus haut a chaque monde.)
for i in range(len(SWORDS), 2 + 3 * WORLDS):
    SWORDS.append((SWORDS[i - 3][0] * 100, SWORDS[i - 3][1] * 100 * LONG_PRICE))
def sword_dps(level): return round(SWORDS[level - 1][0]) / 0.5
LEVEL_GROW = 1.03
def player_need(level): return int(30 * level ** 1.7 * LEVEL_GROW ** (level - 1))  # Config.xpNeed
def monster(world, rank):
    hp, dmg = HP[rank], DMG[rank]
    if world > 0 and rank == 0:
        hp, dmg = FIRST
    return hp * ZONE ** world, dmg * ZONE ** world

class Pet:
    def __init__(self, world, rank, rng):
        pick, grade = rng.uniform(0, 100), 3
        for i, odds in enumerate(GRADE_ODDS):
            pick -= odds
            if pick <= 0:
                grade = i; break
        self.world, self.rank, self.along, self.lv, self.xp = world, rank, (grade + rng.uniform(0.04, 0.96)) / 4, 1, 0
    def factor(self): return (0.7 + 0.6 * self.along) * 1.1 ** (self.lv - 1) * ZONE ** self.world
    def dmg(self): return FIGHT_DMG[self.rank] * self.factor()
    def hp(self): return FIGHT_HP[self.rank] * self.factor()
    def need(self): return int(NEED * (EARLY if self.lv <= 5 else 1) * 1.3 ** (self.lv - 1) * RANK_XP[self.rank] * XP_ZONE ** self.world * LONG_XP[self.world])
    def gain(self, xp):
        self.xp += xp
        while self.xp >= self.need():
            self.xp -= self.need(); self.lv += 1
    def name(self): return 'M%d-r%d niv%d' % (self.world + 1, self.rank + 1, self.lv)

def run(seed):
    rng = random.Random(seed)
    t, coins, sword, level, xp, team, pen, opened = 0.0, 0.0, 1, 1, 0, [], [], 0
    log, bosses = [], []
    while t < 200 * 3600:
        php = 100 * 1.1 ** (level - 1)
        dps = sword_dps(sword) + sum(p.dmg() for p in team)
        def winnable(world, rank):
            hp, dmg = monster(world, rank)
            return hp / dps <= (sum(p.hp() for p in team) + php * 0.6) / (dmg / 1.3), hp / dps
        target = (0, 0)
        for world in range(opened + 1):
            for rank in range(6):
                if winnable(world, rank)[0]:
                    target = (world, rank)
        world, rank = target
        ok, ttk = winnable(world, rank)
        if not ok:
            return None
        dt = ttk + (3 if rank == 5 else WALK)
        t += dt
        coins += COINS[rank] * COIN_ZONE ** world + dt * sum(INCOME[p.rank] * COIN_ZONE ** p.world for p in pen[:8])
        gain = XP[rank] * XP_ZONE ** world
        for p in team: p.gain(gain)
        xp += gain
        while xp >= player_need(level):
            xp -= player_need(level); level += 1
        if rng.random() < EGG[rank] / LONG_EGG[world]:
            pen.append(Pet(world, rank, rng))
            pen.sort(key=lambda p: -p.dmg())
            team = pen[:3]
        if rank == 5 and world == opened:
            bosses.append(t)
            log.append((t, 'BOSS DU MONDE %d BATTU' % (world + 1), sword, level, team))
            opened += 1
            if opened >= WORLDS:
                return bosses, log
        while sword < len(SWORDS) and coins >= SWORDS[sword][1]:
            coins -= SWORDS[sword][1]; sword += 1
            log.append((t, 'EPEE %d : %d/s ; les trois familiers : %d/s' % (sword, sword_dps(sword), sum(p.dmg() for p in team)), sword, level, team))
        if int(t / 1800) > int((t - dt) / 1800):
            log.append((t, 'combat le camp M%d-r%d ; epee %d/s ; familiers %s' % (world + 1, rank + 1, sword_dps(sword), [round(p.dmg()) for p in team]), sword, level, team))
    return None

results = [r for r in (run(s) for s in range(40)) if r]
print('parties finies : %d / 40' % len(results))
previous = [0] * len(results)
for world in range(WORLDS):
    spans = [(r[0][world] - previous[i]) / 3600 for i, r in enumerate(results)]
    previous = [r[0][world] for r in results]
    levels = [r[1][[i for i, step in enumerate(r[1]) if 'BOSS DU MONDE %d' % (world + 1) in step[1]][0]][3] for r in results]
    print('monde %d : mediane %.1f h, min %.1f h, max %.1f h ; niveau du joueur au boss : %d' % (world + 1, statistics.median(spans), min(spans), max(spans), statistics.median(levels)))
if '-v' in sys.argv:
    for step in results[0][1]:
        print('%4.1f h  niveau %2d  %s  [%s]' % (step[0] / 3600, step[3], step[1], ', '.join(p.name() for p in step[4])))
