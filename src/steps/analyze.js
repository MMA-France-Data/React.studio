import path from 'node:path';
import { extractFrames, detectSceneChanges } from './ingest.js';
import { writeJson } from '../lib/fsx.js';
import { log } from '../lib/log.js';

const MIN_GAP = 1.2;     // secondes entre deux repliques
const SPEECH_RATE = 2.9; // mots/seconde, pour estimer la duree d'une replique

/**
 * Produit le script de reaction : quoi dire, quand, sur quelle emotion.
 * Le provider decide du contenu ; cette etape garantit que le resultat est
 * jouable (dans les bornes, ordonne, sans chevauchement).
 */
export async function analyze({ source, info, workDir, persona, config }) {
  const sceneChanges = await detectSceneChanges(source);
  if (sceneChanges.length) {
    log.detail(`temps forts detectes : ${sceneChanges.map((t) => t.toFixed(2) + 's').join(', ')}`);
  }

  const provider = await resolveVisionProvider(config);
  const frames = provider.needsFrames
    ? await extractFrames(source, workDir, { count: config.vision.maxFrames, duration: info.duration })
    : [];

  const raw = await provider.writeScript({
    frames,
    duration: info.duration,
    sceneChanges,
    persona,
    config,
  });

  const script = normalizeScript(raw, info.duration);
  await writeJson(path.join(workDir, 'script.json'), script);

  log.ok(`${script.beats.length} repliques (${script.source})`);
  for (const beat of script.beats) {
    log.detail(`${beat.t.toFixed(2).padStart(6)}s  [${beat.emotion}] ${beat.line}`);
  }
  return script;
}

async function resolveVisionProvider(config) {
  const wanted = config.vision.provider;
  const hasKey = Boolean(config.vision.apiKey);

  if (wanted === 'claude' || (wanted === 'auto' && hasKey)) {
    if (!hasKey) throw new Error('RS_VISION_PROVIDER=claude mais ANTHROPIC_API_KEY est vide.');
    const mod = await import('../providers/vision/claude.js');
    return { writeScript: mod.writeScript, needsFrames: true };
  }

  const mod = await import('../providers/vision/stub.js');
  return { writeScript: mod.writeScript, needsFrames: false };
}

/**
 * Un script sorti d'un modele peut deborder : timecodes hors bornes, repliques
 * qui se marchent dessus, ordre casse. On repare plutot que d'echouer.
 */
export function normalizeScript(raw, duration) {
  const beats = [...(raw.beats ?? [])]
    .filter((beat) => beat && typeof beat.line === 'string' && beat.line.trim())
    .map((beat) => ({
      t: clamp(Number(beat.t) || 0, 0, Math.max(0, duration - 0.5)),
      line: beat.line.trim(),
      emotion: beat.emotion || 'curiosite',
      cue: beat.cue || '',
    }))
    .sort((a, b) => a.t - b.t);

  // Ecarte les repliques trop rapprochees : deux voix qui se superposent
  // rendent le montage inaudible.
  const spaced = [];
  for (const beat of beats) {
    const previous = spaced[spaced.length - 1];
    if (previous && beat.t - previous.t < MIN_GAP) {
      const shifted = previous.t + MIN_GAP;
      if (shifted > duration - 0.5) {
        log.warn(`Replique ignoree, plus de place a la fin : "${beat.line}"`);
        continue;
      }
      beat.t = shifted;
    }
    spaced.push(beat);
  }

  return {
    summary: raw.summary ?? '',
    hook: raw.hook ?? spaced[0]?.line ?? '',
    beats: spaced.map((beat) => ({ ...beat, estimatedDuration: estimateDuration(beat.line) })),
    caption: raw.caption ?? '',
    hashtags: Array.isArray(raw.hashtags) ? raw.hashtags.map((h) => h.replace(/^#/, '')) : [],
    source: raw.source ?? 'inconnu',
  };
}

function estimateDuration(line) {
  return Math.max(0.9, line.split(/\s+/).length / SPEECH_RATE);
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}
