import path from 'node:path';
import fs from 'node:fs/promises';
import { ffmpeg, probe } from '../lib/ffmpeg.js';
import { ffSeconds } from '../lib/time.js';
import { ensureDir } from '../lib/fsx.js';
import { log } from '../lib/log.js';

/** Analyse la video source et verifie qu'elle est exploitable. */
export async function inspectSource(source) {
  const info = await probe(source);

  if (!info.hasVideo) throw new Error(`${source} ne contient pas de piste video.`);
  if (info.duration > 180) {
    log.warn(`Source de ${info.duration.toFixed(0)}s : au-dela de ~60s le format reaction perd son rythme.`);
  }

  log.detail(`${info.width}x${info.height} - ${info.duration.toFixed(2)}s - ${info.fps.toFixed(2)} fps - audio: ${info.hasAudio ? 'oui' : 'non'}`);
  return info;
}

/**
 * Extrait des images reparties sur toute la duree, une par appel ffmpeg pour
 * garder un timecode exact (le filtre fps derive sur les sources a VFR).
 */
export async function extractFrames(source, workDir, { count, duration, width = 512 }) {
  const dir = await ensureDir(path.join(workDir, 'frames'));
  await fs.rm(dir, { recursive: true, force: true });
  await ensureDir(dir);

  const total = Math.max(2, Math.min(count, Math.ceil(duration * 4)));
  const timestamps = Array.from({ length: total }, (_, i) => ((i + 0.5) * duration) / total);
  const frames = [];

  // Par lots : ffmpeg sature vite le disque si on lance 20 process d'un coup.
  const BATCH = 4;
  for (let i = 0; i < timestamps.length; i += BATCH) {
    const batch = timestamps.slice(i, i + BATCH);
    const made = await Promise.all(batch.map(async (t, j) => {
      const index = i + j;
      const file = path.join(dir, `f${String(index).padStart(3, '0')}.jpg`);
      await ffmpeg([
        '-ss', ffSeconds(t),
        '-i', source,
        '-frames:v', '1',
        '-vf', `scale=${width}:-2`,
        '-q:v', '4',
        file,
      ]);
      return { t, file };
    }));
    frames.push(...made);
  }

  log.detail(`${frames.length} images extraites (une toutes les ${(duration / total).toFixed(2)}s)`);
  return frames;
}

/**
 * Temps forts detectes par changement de scene. Sert de repli quand aucun
 * modele de vision n'est disponible, et de garde-fou pour le calage.
 */
export async function detectSceneChanges(source, threshold = 0.12) {
  const { stdout } = await runSceneDetect(source, threshold);
  const times = [];

  for (const line of stdout.split('\n')) {
    const match = line.match(/pts_time:([0-9.]+)/);
    if (match) times.push(Number(match[1]));
  }
  return times;
}

async function runSceneDetect(source, threshold) {
  const { spawn } = await import('node:child_process');

  return new Promise((resolve) => {
    const child = spawn('ffmpeg', [
      '-hide_banner', '-loglevel', 'info',
      '-i', source,
      '-filter:v', `select='gt(scene,${threshold})',metadata=print:file=-`,
      '-an', '-f', 'null', '-',
    ], { stdio: ['ignore', 'pipe', 'pipe'] });

    let stdout = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', () => {});
    child.on('error', () => resolve({ stdout: '' }));
    child.on('close', () => resolve({ stdout }));
  });
}
