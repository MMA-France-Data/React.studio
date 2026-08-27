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
  log.detail(describeLayout(layout));

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

/**
 * Decrit ou se pose chaque element du cadre. Deux modes :
 *
 * - `split` : la source en haut, le personnage en bas. Pour les sources
 *   horizontales, ou l'empilement ne coute rien.
 * - `pip`   : la source en plein cadre, le personnage dans une bulle. Pour les
 *   sources verticales, qu'un empilement reduirait au tiers du cadre.
 *
 * Toutes les dimensions sont paires : libx264 en yuv420p refuse les impaires.
 */
export function computeLayout({
  width, height, topRatio, layout = 'split',
  pipScale = 0.34, pipMargin = 0.05, pipBottom = 0.15, pipPosition = 'bottom-left',
}) {
  const even = (n) => Math.round(n / 2) * 2;
  const frameWidth = even(width);
  const frameHeight = even(height);

  if (layout === 'pip') {
    const size = even(clamp(pipScale, 0.18, 0.6) * frameWidth);
    const marginX = Math.round(clamp(pipMargin, 0, 0.3) * frameWidth);
    const marginY = Math.round(clamp(pipBottom, 0, 0.5) * frameHeight);
    const atTop = pipPosition.startsWith('top');

    const x = pipPosition.endsWith('right') ? frameWidth - size - marginX : marginX;
    const y = atTop ? marginY : frameHeight - size - marginY;

    return {
      mode: 'pip',
      width: frameWidth,
      height: frameHeight,
      source: { width: frameWidth, height: frameHeight, x: 0, y: 0 },
      reactor: { width: size, height: size, x, y },
      // Les sous-titres se posent au-dessus de la bulle, jamais dessus.
      captionsBottom: atTop
        ? Math.round(frameHeight * 0.14)
        : frameHeight - y + Math.round(frameHeight * 0.02),
    };
  }

  const top = even(frameHeight * clamp(topRatio, 0.35, 0.85));

  return {
    mode: 'split',
    width: frameWidth,
    height: frameHeight,
    source: { width: frameWidth, height: top, x: 0, y: 0 },
    reactor: { width: frameWidth, height: frameHeight - top, x: 0, y: top },
    captionsBottom: (frameHeight - top) + Math.round(frameHeight * 0.02),
  };
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

/** Une ligne lisible dans les logs : ce que le monteur va reellement produire. */
function describeLayout(layout) {
  const size = `sortie ${layout.width}x${layout.height}`;
  return layout.mode === 'pip'
    ? `${size} - source plein cadre, personnage en bulle de ${layout.reactor.width}px`
    : `${size} - source ${layout.source.height}px / personnage ${layout.reactor.height}px`;
}

export { DEFAULT_PERSONA };
