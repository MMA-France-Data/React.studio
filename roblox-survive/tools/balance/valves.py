"""Simulation hors Studio de la salle des vannes (meme regles que src/server/Events/Valves.luau), pour regler ses
temps de remplissage sur beaucoup de manches (la salle a du hasard : une seule manche ne dit rien).

    python tools/balance/valves.py            -> tableau : pour chaque vitesse, la part des manches perdues

Le joueur simule va vers la vanne la plus urgente et ne change d'avis qu'une fois arrive ; `late` = secondes perdues
a chaque changement de vanne (hesitation).
"""
import math, random, sys

SPOTS = [(-27, -31), (27, -31), (27, 31), (-27, 31)]
CLOSE, STOP = 6.0, 3.0
SHUFFLE, GRACE, DURATION = 12.0, 3.0, 60.0
NEED_SPEED = 16 + 5 * (2 + math.log(10000 / 2500) / math.log(20))  # la vitesse a 10 000 points


def run(speed, late, fills, seed, strikes=3):
    rnd = random.Random(seed)
    perimeter = sum(math.dist(SPOTS[i], SPOTS[(i + 1) % 4]) for i in range(4))
    lap = perimeter / NEED_SPEED
    current = fills[:]
    rnd.shuffle(current)
    pressure = [0.0] * 4
    pos = [0.0, -32.0]
    t, dt, shuffle, bursts, target, wait = 0.0, 1 / 30, SHUFFLE, 0, -1, 0.0
    while t < DURATION:
        t += dt
        shuffle -= dt
        if shuffle <= 0:
            shuffle = SHUFFLE
            rnd.shuffle(current)
        arrived = target < 0 or math.dist(pos, SPOTS[target]) <= STOP + 0.5
        if arrived:
            best, slack = 0, 1e9
            for i in range(4):
                left = (1 - pressure[i]) * current[i] * lap - math.dist(pos, SPOTS[i]) / speed
                if left < slack:
                    best, slack = i, left
            if best != target:
                target, wait = best, late
        wait -= dt
        if wait <= 0:
            d = math.dist(pos, SPOTS[target])
            if d > STOP:
                step = min(d - STOP, speed * dt)
                pos[0] += (SPOTS[target][0] - pos[0]) / d * step
                pos[1] += (SPOTS[target][1] - pos[1]) / d * step
        for i in range(4):
            if math.dist(pos, SPOTS[i]) <= CLOSE:
                pressure[i] = 0
            elif t >= GRACE:
                pressure[i] += dt / (current[i] * lap)
                if pressure[i] >= 1:
                    pressure[i] = 0
                    bursts += 1
                    if bursts >= strikes:
                        return bursts, t
    return bursts, t


def speed_of(points):
    tiers = [120, 2500, 50000, 1000000]
    if points < 120:
        return 16 + 5 * points / 120
    for n in range(len(tiers) - 1):
        if points < tiers[n + 1]:
            return 16 + 5 * (n + 1 + math.log(points / tiers[n]) / math.log(tiers[n + 1] / tiers[n]))
    return 16 + 5 * len(tiers)


if __name__ == '__main__':
    base = [1.1, 1.6, 1.6, 2.2]
    for factor in [float(a) for a in sys.argv[1:]] or [1.0, 1.1, 1.2, 1.3]:
        fills = [f * factor for f in base]
        print('remplissage x %.2f : %s tours de salle' % (factor, ', '.join('%.2f' % f for f in fills)))
        for points, late in [(10000, 0), (10000, 0.4), (10000, 0.8), (5000, 0.4), (2500, 0), (2500, 0.4), (1000, 0), (1000, 0.4), (150, 0), (0, 0)]:
            results = [run(speed_of(points), late, fills, seed) for seed in range(300)]
            lost = sum(1 for b, _ in results if b >= 3) / len(results)
            mean = sum(b for b, _ in results) / len(results)
            print('   %6d points (court a %.1f), hesite %.1f s : perd %3.0f %% des manches, %.1f explosions en moyenne' % (points, speed_of(points), late, lost * 100, mean))
