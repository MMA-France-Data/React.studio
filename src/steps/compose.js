import path from 'node:path';
import fs from 'node:fs/promises';
import { ffmpeg, escapeFilterValue } from '../lib/ffmpeg.js';
import { ffSeconds } from '../lib/time.js';
import { buildAss } from '../lib/ass.js';
import { buildSrt } from '../lib/srt.js';
import { log } from '../lib/log.js';

const RING_WIDTH = 6; // epaisseur du liseré autour de la bulle, en pixels

/**
 * Montage final : la source, le personnage, les repliques incrustees et le son
 * de la source attenue sous la voix. Tout en une passe ffmpeg, pour eviter les
 * reencodages successifs.
 */
export async function compose({ source, sourceInfo, reactorFile, voiceTrack, clips, layout, duration, outFile, workDir, config }) {
  const { fps, disclosure, font } = config.render;

  const cues = clips.map((clip) => ({ start: clip.start, end: clip.end, text: clip.line }));
  const assFile = path.join(workDir, 'captions.ass');
  const srtFile = outFile.replace(/\.mp4$/, '.srt');

  await fs.writeFile(assFile, buildAss(cues, {
    width: layout.width,
    height: layout.height,
    marginBottom: layout.captionsBottom,
  }), 'utf8');
  await fs.writeFile(srtFile, buildSrt(cues), 'utf8');

  const inputs = ['-i', source, '-i', reactorFile, '-i', voiceTrack];

  // Le liseré de la bulle est un cercle plein, pose sous le personnage.
  if (layout.mode === 'pip') {
    const ringSize = layout.reactor.width + RING_WIDTH * 2;
    inputs.push('-f', 'lavfi', '-i', `color=c=0xF5F5F5:s=${ringSize}x${ringSize}:d=${ffSeconds(duration)}:r=${fps}`);
  }

  const filters = [
    ...buildVideoFilters({ layout, fps, duration, disclosure, font, assFile }),
    ...buildAudioFilters({ hasSourceAudio: sourceInfo.hasAudio }),
  ];

  await ffmpeg([
    ...inputs,
    '-filter_complex', filters.join(';'),
    '-map', '[vout]',
    '-map', '[aout]',
    '-t', ffSeconds(duration),
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '19',
    '-profile:v', 'high', '-pix_fmt', 'yuv420p',
    '-r', String(fps),
    '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
    '-movflags', '+faststart',
    outFile,
  ], `montage final (${layout.mode})`);

  log.ok(`montage : ${path.basename(outFile)}`);
  return { outFile, srtFile };
}

function buildVideoFilters({ layout, fps, duration, disclosure, font, assFile }) {
  const chains = layout.mode === 'pip'
    ? buildPipChains({ layout, fps, duration })
    : buildSplitChains({ layout, fps, duration });

  let label = 'composed';

  if (disclosure && font) {
    chains.push(`[${label}]${drawtext({
      font,
      text: disclosure,
      size: Math.round(layout.width * 0.024),
      x: `w-text_w-${Math.round(layout.width * 0.03)}`,
      y: Math.round(layout.width * 0.03),
      color: 'white@0.9',
      box: true,
    })}[labelled]`);
    label = 'labelled';
  }

  chains.push(`[${label}]subtitles=${escapeFilterValue(assFile)}[vout]`);
  return chains;
}

/** Source en haut, personnage en bas, empiles. */
function buildSplitChains({ layout, fps, duration }) {
  const { width } = layout;
  const top = layout.source.height;

  return [
    ...fitSource('[0:v]', { fps, width, height: top, out: 'top' }),
    fitReactor('[1:v]', { fps, duration, ...layout.reactor, out: 'bottom' }),
    `[top][bottom]vstack=inputs=2[stacked]`,
    `[stacked]drawbox=x=0:y=${top - 2}:w=${width}:h=4:color=0x0A0A0A@0.9:t=fill[composed]`,
  ];
}

/**
 * Source en plein cadre, personnage dans une bulle ronde. C'est le format qui
 * rend justice aux sources verticales : elles gardent tout le cadre.
 */
function buildPipChains({ layout, fps, duration }) {
  const { width, height, reactor } = layout;

  return [
    ...fitSource('[0:v]', { fps, width, height, out: 'base' }),
    fitReactor('[1:v]', { fps, duration, ...reactor, out: 'square' }),
    `[square]${circleMask()}[bubble]`,
    `[3:v]${circleMask()}[ring]`,
    `[base][ring]overlay=x=${reactor.x - RING_WIDTH}:y=${reactor.y - RING_WIDTH}:shortest=0[ringed]`,
    `[ringed][bubble]overlay=x=${reactor.x}:y=${reactor.y}:shortest=0[composed]`,
  ];
}

/**
 * Remplit un cadre sans jamais rogner le sujet : un fond flou recadre en dessous,
 * l'image entiere par-dessus. Fonctionne quel que soit le format de la source.
 */
function fitSource(input, { fps, width, height, out }) {
  return [
    `${input}fps=${fps},setsar=1,split=2[${out}_bg][${out}_fg]`,
    `[${out}_bg]scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},boxblur=24:2,eq=brightness=-0.10:saturation=0.7[${out}_blur]`,
    `[${out}_fg]scale=${width}:${height}:force_original_aspect_ratio=decrease[${out}_fit]`,
    `[${out}_blur][${out}_fit]overlay=(W-w)/2:(H-h)/2:shortest=0,setsar=1[${out}]`,
  ];
}

/**
 * Le personnage, lui, est recadre pour remplir : c'est un visage, on veut qu'il
 * occupe le cadre. La duree est calee exactement — dernier cadre fige si le
 * provider a rendu trop court, coupe s'il a rendu trop long.
 */
function fitReactor(input, { fps, duration, width, height, out }) {
  return `${input}fps=${fps},scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},setsar=1,`
    + `tpad=stop_mode=clone:stop_duration=${ffSeconds(duration)},trim=0:${ffSeconds(duration)},setpts=PTS-STARTPTS[${out}]`;
}

/**
 * Decoupe un cercle dans un cadre carre. Le bord est adouci sur un pixel :
 * un masque binaire donne un escalier visible sur un visage.
 */
function circleMask() {
  return "format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':"
    + "a='clip(255*((W/2-1)-hypot(X-W/2,Y-H/2)),0,255)'";
}

function buildAudioFilters({ hasSourceAudio }) {
  const voice = '[2:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,volume=1.6';

  if (!hasSourceAudio) {
    return [`${voice},alimiter=limit=0.95[aout]`];
  }

  return [
    `${voice},asplit=2[voice_mix][voice_key]`,
    `[0:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,volume=0.85[src]`,
    // La voix pilote la compression du son source : la source baisse d'elle-meme
    // quand le personnage parle, et remonte des qu'il se tait.
    `[src][voice_key]sidechaincompress=threshold=0.03:ratio=12:attack=12:release=320:makeup=1[ducked]`,
    `[ducked][voice_mix]amix=inputs=2:normalize=0:dropout_transition=0,alimiter=limit=0.95[aout]`,
  ];
}

function drawtext({ font, text, size, x, y, color, box }) {
  const parts = [
    'drawtext',
    `=fontfile=${escapeFilterValue(font)}`,
    `:text=${escapeFilterValue(text)}`,
    `:fontsize=${size}`,
    `:fontcolor=${color}`,
    `:x=${x}`,
    `:y=${y}`,
  ];
  if (box) parts.push(':box=1:boxcolor=0x000000@0.45:boxborderw=14');
  return parts.join('');
}
