import path from 'node:path';
import fs from 'node:fs/promises';
import { ffmpeg, escapeFilterValue } from '../lib/ffmpeg.js';
import { ffSeconds } from '../lib/time.js';
import { buildAss } from '../lib/ass.js';
import { buildSrt } from '../lib/srt.js';
import { log } from '../lib/log.js';

/**
 * Montage final : video source en haut, personnage en bas, repliques incrustees,
 * son de la source attenue sous la voix. Tout se fait en une passe ffmpeg pour
 * eviter les pertes de reencodage successives.
 */
export async function compose({ source, sourceInfo, reactorFile, voiceTrack, clips, layout, duration, outFile, workDir, config }) {
  const { width, fps, disclosure, font } = config.render;

  const cues = clips.map((clip) => ({ start: clip.start, end: clip.end, text: clip.line }));
  const assFile = path.join(workDir, 'captions.ass');
  const srtFile = outFile.replace(/\.mp4$/, '.srt');

  await fs.writeFile(assFile, buildAss(cues, {
    width,
    height: layout.height,
    // Les sous-titres se posent juste au-dessus du personnage, dans la video source.
    marginBottom: layout.bottom.height + Math.round(layout.height * 0.02),
  }), 'utf8');
  await fs.writeFile(srtFile, buildSrt(cues), 'utf8');

  const filters = [
    ...buildVideoFilters({ layout, fps, duration, disclosure, font, assFile }),
    ...buildAudioFilters({ hasSourceAudio: sourceInfo.hasAudio }),
  ];

  await ffmpeg([
    '-i', source,
    '-i', reactorFile,
    '-i', voiceTrack,
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
  ], 'montage final');

  log.ok(`montage : ${path.basename(outFile)}`);
  return { outFile, srtFile };
}

function buildVideoFilters({ layout, fps, duration, disclosure, font, assFile }) {
  const { width, height } = layout;
  const top = layout.top.height;
  const bottom = layout.bottom.height;

  const chains = [
    // Source : fond flou recadre plein cadre + image entiere par-dessus. Aucune
    // perte de contenu quel que soit le format d'origine (portrait ou paysage).
    `[0:v]fps=${fps},setsar=1,split=2[srcbg][srcfg]`,
    `[srcbg]scale=${width}:${top}:force_original_aspect_ratio=increase,crop=${width}:${top},boxblur=24:2,eq=brightness=-0.10:saturation=0.7[topbg]`,
    `[srcfg]scale=${width}:${top}:force_original_aspect_ratio=decrease[topfg]`,
    `[topbg][topfg]overlay=(W-w)/2:(H-h)/2:shortest=0,setsar=1[top]`,

    // Personnage : recadrage centre, puis calage exact sur la duree (le dernier
    // cadre est fige si le provider a rendu trop court).
    `[1:v]fps=${fps},scale=${width}:${bottom}:force_original_aspect_ratio=increase,crop=${width}:${bottom},setsar=1,` +
      `tpad=stop_mode=clone:stop_duration=${ffSeconds(duration)},trim=0:${ffSeconds(duration)},setpts=PTS-STARTPTS[bottom]`,

    `[top][bottom]vstack=inputs=2[stacked]`,
    `[stacked]drawbox=x=0:y=${top - 2}:w=${width}:h=4:color=0x0A0A0A@0.9:t=fill[seam]`,
  ];

  let label = 'seam';

  if (disclosure && font) {
    chains.push(`[${label}]${drawtext({
      font,
      text: disclosure,
      size: Math.round(width * 0.024),
      x: `w-text_w-${Math.round(width * 0.03)}`,
      y: Math.round(width * 0.03),
      color: 'white@0.9',
      box: true,
    })}[labelled]`);
    label = 'labelled';
  }

  chains.push(`[${label}]subtitles=${escapeFilterValue(assFile)}[vout]`);
  return chains;
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
