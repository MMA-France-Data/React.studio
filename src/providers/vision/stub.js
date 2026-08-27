import { log } from '../../lib/log.js';

/**
 * Repli sans modele de vision : les repliques sont generiques mais le calage
 * est reel (changements de plan, sinon repartition reguliere). Sert a valider
 * le montage et le rythme avant de brancher une cle API.
 */
const LINES = [
  { line: 'Attends attends, regarde bien ce truc.', emotion: 'curiosite' },
  { line: 'Non mais il est serieux la ?', emotion: 'choc' },
  { line: 'J etais pas pret pour ca.', emotion: 'rire' },
  { line: 'Franchement, respect.', emotion: 'admiration' },
  { line: 'Rejoue-moi ca au ralenti.', emotion: 'rire' },
  { line: 'Bon. On va dire que c est normal.', emotion: 'agacement' },
];

export async function writeScript({ duration, sceneChanges, persona }) {
  log.warn('Provider de vision "stub" : les repliques sont des placeholders, seul le calage est reel.');

  const anchors = pickAnchors(duration, sceneChanges);
  const beats = anchors.map((t, i) => ({
    t,
    line: LINES[i % LINES.length].line,
    emotion: LINES[i % LINES.length].emotion,
    cue: 'placeholder - aucun modele de vision n a analyse cette image',
  }));

  return {
    summary: 'Analyse indisponible : aucun modele de vision configure.',
    hook: beats[0]?.line ?? 'Regarde ca.',
    beats,
    caption: 'Legende a ecrire (script placeholder).',
    hashtags: ['fyp', 'pourtoi'],
    source: 'stub',
  };
}

/** Un temps fort toutes les ~3,5 s, aligne sur les coupes quand il y en a. */
function pickAnchors(duration, sceneChanges) {
  const target = Math.max(2, Math.min(5, Math.round(duration / 3.5)));
  const usable = sceneChanges.filter((t) => t > 0.6 && t < duration - 1.2);

  if (usable.length >= target) {
    const stride = usable.length / target;
    return Array.from({ length: target }, (_, i) => usable[Math.floor(i * stride)]);
  }

  const anchors = [0.4];
  for (let i = 1; i < target; i += 1) anchors.push((i * duration) / target);
  return anchors.filter((t) => t < duration - 0.8);
}
