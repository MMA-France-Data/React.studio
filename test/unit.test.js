import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAss } from '../src/lib/ass.js';
import { buildSrt } from '../src/lib/srt.js';
import { wrapLines } from '../src/lib/text.js';
import { slugify } from '../src/lib/fsx.js';
import { computeLayout } from '../src/pipeline.js';
import { normalizeScript } from '../src/steps/analyze.js';

test('ASS : la ligne Format declare les 10 colonnes attendues par libass', () => {
  const ass = buildAss([{ start: 1, end: 2, text: 'Salut' }], { width: 1080, height: 1920, marginBottom: 800 });
  const format = ass.split('\n').find((line) => line.startsWith('Format: Layer'));

  assert.equal(format.split(',').length, 10, 'MarginV manquant = premier caractere du texte avale');
  const dialogue = ass.split('\n').find((line) => line.startsWith('Dialogue:'));
  assert.ok(dialogue.endsWith(',Salut'), `texte mal aligne : ${dialogue}`);
});

test('ASS : la resolution declaree suit la video, pour des tailles en pixels', () => {
  const ass = buildAss([], { width: 720, height: 1280, marginBottom: 400 });
  assert.match(ass, /PlayResX: 720/);
  assert.match(ass, /PlayResY: 1280/);
});

test('sous-titres : une replique qui deborde sur la suivante est tronquee', () => {
  const srt = buildSrt([
    { start: 1, end: 5, text: 'Premiere' },
    { start: 3, end: 6, text: 'Seconde' },
  ]);
  assert.match(srt, /00:00:01,000 --> 00:00:02,920/);
});

test('layout : hauteurs paires et somme egale a la hauteur de sortie', () => {
  for (const ratio of [0.35, 0.5, 0.6, 0.77]) {
    const layout = computeLayout({ width: 1080, height: 1920, topRatio: ratio });
    assert.equal(layout.top.height % 2, 0);
    assert.equal(layout.bottom.height % 2, 0);
    assert.equal(layout.top.height + layout.bottom.height, 1920);
  }
});

test('layout : un ratio aberrant est ramene dans des bornes jouables', () => {
  assert.ok(computeLayout({ width: 1080, height: 1920, topRatio: 5 }).bottom.height > 0);
  assert.ok(computeLayout({ width: 1080, height: 1920, topRatio: -3 }).top.height > 0);
});

test('script : les repliques sont ordonnees, espacees et dans les bornes', () => {
  const script = normalizeScript({
    beats: [
      { t: 8.4, line: 'Troisieme', emotion: 'rire' },
      { t: 0.2, line: 'Premiere', emotion: 'choc' },
      { t: 0.5, line: 'Trop pres de la premiere', emotion: 'rire' },
      { t: 99, line: 'Hors bornes', emotion: 'peur' },
      { t: 2, line: '   ', emotion: 'rire' },
    ],
  }, 10);

  const times = script.beats.map((b) => b.t);
  assert.deepEqual(times, [...times].sort((a, b) => a - b), 'ordre chronologique');
  for (let i = 1; i < times.length; i += 1) {
    assert.ok(times[i] - times[i - 1] >= 1.2 - 1e-9, `repliques trop rapprochees : ${times}`);
  }
  assert.ok(times.every((t) => t <= 9.5), 'timecode hors de la video');
  assert.ok(script.beats.every((b) => b.line.trim()), 'replique vide conservee');
  assert.ok(script.beats.every((b) => b.estimatedDuration > 0));
});

test('slugify : accents et espaces donnent un nom de fichier sain', () => {
  assert.equal(slugify('/videos/Mon Clip Éléphant.MP4'), 'mon-clip-elephant');
  assert.equal(slugify('/videos/!!!.mp4'), 'reaction');
});

test('sous-titres : la ponctuation double francaise ne saute pas seule a la ligne', () => {
  const cues = [{ start: 1, end: 3, text: 'Non mais il est serieux la ?' }];

  const dialogue = buildAss(cues, { width: 1080, height: 1920, marginBottom: 800 })
    .split('\n').find((line) => line.startsWith('Dialogue:'));
  assert.ok(!/\\N\s*\?/.test(dialogue), `« ? » isole sur sa ligne : ${dialogue}`);
  assert.ok(dialogue.includes('la\\h?'), 'espace insecable ASS attendue avant « ? »');

  const srt = buildSrt(cues);
  assert.ok(!/\n\?/.test(srt), '« ? » isole en debut de ligne dans le SRT');
});

test('retour a la ligne : les lignes respectent la largeur demandee', () => {
  const lines = wrapLines('Attends attends regarde bien ce truc la tout de suite', 20);
  assert.ok(lines.length > 1);
  assert.ok(lines.every((line) => line.length <= 20), `ligne trop longue : ${JSON.stringify(lines)}`);
});
