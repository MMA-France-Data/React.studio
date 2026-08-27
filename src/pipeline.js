import path from 'node:path';
import fs from 'node:fs/promises';
import { inspectSource } from './steps/ingest.js';
import { analyze } from './steps/analyze.js';
import { synthesizeVoice } from './steps/voice.js';
import { renderReactor } from './steps/avatar.js';
import { compose } from './steps/compose.js';
import { ensureDir, writeJson, slugify } from './lib/fsx.js';
import { log } from './lib/log.js';

const DEFAULT_PERSONA =
  'un spectateur expressif et bienveillant, qui commente a voix haute, se laisse surprendre et fait rire sans se moquer';

export async function render({ source, persona = DEFAULT_PERSONA, outFile, outDir = 'out', keepWork = false, config }) {
  log.reset();
  const startedAt = Date.now();

  const slug = slugify(source);
  const finalOut = outFile || path.join(outDir, `${slug}-reaction.mp4`);
  const workDir = await ensureDir(path.join(outDir, '.work', slug));
  await ensureDir(path.dirname(finalOut));

  log.step('Lecture de la video source');
  const sourceInfo = await inspectSource(source);
  const layout = computeLayout(config.render);
  log.detail(`sortie ${layout.width}x${layout.height} - source ${layout.top.height}px / personnage ${layout.bottom.height}px`);

  log.step('Ecriture du script de reaction');
  const script = await analyze({ source, info: sourceInfo, workDir, persona, config });

  log.step('Synthese de la voix');
  const { voiceTrack, clips } = await synthesizeVoice({
    script,
    duration: sourceInfo.duration,
    workDir,
    config,
  });

  log.step('Rendu du personnage');
  const reactor = await renderReactor({
    voiceTrack,
    workDir,
    layout,
    duration: sourceInfo.duration,
    persona,
    config,
  });

  log.step('Montage 9:16');
  const { srtFile } = await compose({
    source,
    sourceInfo,
    reactorFile: reactor.file,
    voiceTrack,
    clips,
    layout,
    duration: sourceInfo.duration,
    outFile: finalOut,
    workDir,
    config,
  });

  const metaFile = finalOut.replace(/\.mp4$/, '.json');
  await writeJson(metaFile, {
    source,
    persona,
    duration: sourceInfo.duration,
    layout,
    script,
    providers: {
      vision: script.source,
      tts: config.tts.provider,
      avatar: config.avatar.provider,
    },
    disclosure: config.render.disclosure,
    generatedWith: 'reaction-studio',
  });

  if (!keepWork) await fs.rm(workDir, { recursive: true, force: true });

  const seconds = ((Date.now() - startedAt) / 1000).toFixed(1);
  log.result(`Termine en ${seconds}s\n  video     ${finalOut}\n  sous-titres ${srtFile}\n  metadonnees ${metaFile}`);

  if (script.caption) log.info(`Legende  : ${script.caption}`);
  if (script.hashtags?.length) log.info(`Hashtags : ${script.hashtags.map((h) => '#' + h).join(' ')}`);
  if (reactor.placeholder) {
    log.warn('Le personnage est un placeholder. Branchez un provider (RS_AVATAR_PROVIDER=cmd) pour un rendu realiste.');
  }

  return { outFile: finalOut, srtFile, metaFile, script };
}

/** Deux panneaux empiles, hauteurs paires (exigence de libx264 en yuv420p). */
export function computeLayout({ width, height, topRatio }) {
  const even = (n) => Math.round(n / 2) * 2;
  const ratio = Math.min(0.85, Math.max(0.35, topRatio));
  const top = even(height * ratio);

  return {
    width: even(width),
    height: even(height),
    top: { width: even(width), height: top },
    bottom: { width: even(width), height: even(height) - top },
  };
}

export { DEFAULT_PERSONA };
