import path from 'node:path';
import { probe } from '../lib/ffmpeg.js';
import { exists } from '../lib/fsx.js';
import { log } from '../lib/log.js';

/** Genere la video du personnage qui reagit, a la taille du panneau du bas. */
export async function renderReactor({ voiceTrack, workDir, layout, duration, persona, config }) {
  const outFile = path.join(workDir, 'reactor.mp4');
  const provider = config.avatar.provider;

  const options = {
    voiceTrack,
    outFile,
    duration,
    width: layout.reactor.width,
    height: layout.reactor.height,
    fps: config.render.fps,
    persona,
    image: config.avatar.reactorImage,
    font: config.render.font,
    cmd: config.avatar.cmd,
  };

  if (config.avatar.reactorImage && !(await exists(config.avatar.reactorImage))) {
    throw new Error(`Portrait introuvable : ${config.avatar.reactorImage}`);
  }

  const mod = provider === 'cmd'
    ? await import('../providers/avatar/cmd.js')
    : await import('../providers/avatar/placeholder.js');

  const result = await mod.render(options);

  if (!(await exists(outFile))) {
    throw new Error(`Le provider avatar "${provider}" n'a produit aucun fichier a ${outFile}`);
  }

  const info = await probe(outFile);
  if (Math.abs(info.duration - duration) > 0.5) {
    log.warn(`Le clip du personnage fait ${info.duration.toFixed(2)}s pour ${duration.toFixed(2)}s attendues : il sera cale au montage.`);
  }

  log.ok(`personnage : ${provider}${result.placeholder ? ' (placeholder)' : ''}`);
  return { file: outFile, ...result };
}
