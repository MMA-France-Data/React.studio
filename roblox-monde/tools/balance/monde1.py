# Simulation grossière du monde 1 : combien de temps avant de battre le boss ?
# Un joueur « malin » : il farme toujours le camp le plus haut qu'il peut gagner, garde ses trois meilleurs
# familiers, achète l'épée dès qu'il peut. Les chiffres doivent être les mêmes que Config.luau et Pets.luau.
import random, statistics, sys

HP = [40, 300, 700, 1500, 3200, 9000]
DMG = [3, 15, 30, 60, 125, 400]
COINS = [3, 8, 20, 50, 130, 2000]
XP = [4, 10, 24, 55, 130, 600]
EGG = [0.20, 0.05, 0.03, 0.02, 0.012, 0.02]
FIGHT_DMG = [5, 10, 20, 40, 85, 600]
FIGHT_HP = [45, 90, 180, 360, 760, 5400]
RANK_XP = [1, 2.5, 6, 14, 32, 80]
GRADE_ODDS = [70, 25, 4.6, 0.4]
SWORD_MAX = 5
WALK = 4.0          # secondes pour aller d'un monstre au suivant
INCOME = [0.35, 1.0, 3.75, 18, 90, 1050]  # pièces par seconde d'un familier moyen de chaque rang (valeur / 1000)

def sword_dps(level): return round(1.5 * 3.2 ** (level - 1)) / 0.5
PRICE, PRICE_STEP, NEED = 1000, 6, 45
def sword_price(level): return int(PRICE * PRICE_STEP ** (level - 1))
def pet_need(rank, lv): return int(NEED * 1.3 ** (lv - 1) * RANK_XP[rank])

class Pet:
    def __init__(self, rank, rng):
        pick, grade = rng.uniform(0, 100), 3
        for i, odds in enumerate(GRADE_ODDS):
            pick -= odds
            if pick <= 0:
                grade = i; break
        self.rank, self.along, self.lv, self.xp = rank, (grade + rng.uniform(0.04, 0.96)) / 4, 1, 0
    def factor(self): return (0.7 + 0.6 * self.along) * 1.1 ** (self.lv - 1)
    def dmg(self): return FIGHT_DMG[self.rank] * self.factor()
    def hp(self): return FIGHT_HP[self.rank] * self.factor()
    def gain(self, xp):
        self.xp += xp
        while self.xp >= pet_need(self.rank, self.lv):
            self.xp -= pet_need(self.rank, self.lv); self.lv += 1

def run(seed):
    rng = random.Random(seed)
    t, coins, sword, level, xp, team, pen = 0.0, 0.0, 1, 1, 0, [], []
    log = []
    while t < 40 * 3600:
        php = 100 * 1.1 ** (level - 1)
        dps = sword_dps(sword) + sum(p.dmg() for p in team)
        def winnable(r):
            ttk = HP[r] / dps
            survive = (sum(p.hp() for p in team) + php * 0.6) / (DMG[r] / 1.3)
            return ttk <= survive, ttk
        target = 0
        for r in range(6):
            ok, _ = winnable(r)
            if ok: target = r
        ok, ttk = winnable(target)
        if not ok:
            return None
        dt = ttk + (3 if target == 5 else WALK)
        t += dt
        coins += COINS[target] + dt * sum(INCOME[p.rank] for p in pen[:8])
        for p in team: p.gain(XP[target])
        xp += XP[target]
        while xp >= int(30 * level ** 1.7):
            xp -= int(30 * level ** 1.7); level += 1
        if target == 5:
            log.append((t, 'boss battu', sword, level, [(p.rank + 1, p.lv) for p in team]))
            return t, log
        if rng.random() < EGG[target]:
            new = Pet(target, rng)
            pen.append(new)
            team = sorted(pen, key=lambda p: -p.dmg())[:3]
            if len(log) < 60 and (not log or log[-1][1] != target):
                log.append((t, target, sword, level, [(p.rank + 1, p.lv) for p in team]))
        while sword < SWORD_MAX and coins >= sword_price(sword):
            coins -= sword_price(sword); sword += 1
    return None

results = [run(s) for s in range(40)]
times = [r[0] / 3600 for r in results if r]
print('parties finies : %d / %d' % (len(times), len(results)))
print('heures avant le boss : mediane %.1f, min %.1f, max %.1f' % (statistics.median(times), min(times), max(times)))
if '-v' in sys.argv:
    for step in results[0][1]:
        print('%5.0f min  %s  epee %d  niveau %d  equipe %s' % (step[0] / 60, step[1], step[2], step[3], step[4]))
