import { ffmpeg, escapeFilterValue } from '../../lib/ffmpeg.js';
import { ffSeconds } from '../../lib/time.js';

/**
 * Personnage de substitution genere localement. Ce n'est pas un avatar :
 * c'est une maquette animee par l'enveloppe de la voix, faite pour valider le
 * montage, le cadrage et le timing avant de payer un rendu.
 */
export async function render({ voiceTrack, outFile, width, height, duration, fps, persona, image, font }) {
  const inputs = [];
  const chains = [];
  let videoLabel;

  if (image) {
    inputs.push('-loop', '1', '-t', ffSeconds(duration), '-i', image);
    chains.push(`[0:v]scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},setsar=1,fps=${fps}[base]`);
    videoLabel = 'base';
  } else {
    inputs.push('-f', 'lavfi', '-i', `color=c=0x0E1116:s=${width}x${height}:d=${ffSeconds(duration)}:r=${fps}`);
    chains.push(`[0:v]setsar=1[base]`);
    videoLabel = 'base';
  }

  // La voix est toujours la seconde entree, quelle que soit la source du fond.
  inputs.push('-i', voiceTrack);
  const audioIndex = 1;

  const waveHeight = Math.round(height * 0.24);
  chains.push(
    `[${audioIndex}:a]showwaves=s=${width}x${waveHeight}:mode=cline:colors=0x35D0FF|0x8A7BFF:rate=${fps},format=rgba,colorchannelmixer=aa=0.9[wave]`,
  );
  chains.push(`[${videoLabel}][wave]overlay=0:${Math.round(height * 0.58)}:shortest=0[withwave]`);

  const label = shorten(persona, 30);
  const textChain = font
    ? `[withwave]${drawtext(font, label, Math.round(width * 0.052), `(w-text_w)/2`, Math.round(height * 0.18), 'white')},` +
      `${drawtext(font, 'PERSONNAGE PLACEHOLDER', Math.round(width * 0.026), `(w-text_w)/2`, Math.round(height * 0.18) + Math.round(width * 0.075), '0x8A94A6')}[v]`
    : `[withwave]null[v]`;
  chains.push(textChain);

  await ffmpeg([
    ...inputs,
    '-filter_complex', chains.join(';'),
    '-map', '[v]',
    '-an',
    '-t', ffSeconds(duration),
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p',
    outFile,
  ], 'personnage placeholder');

  return { outFile, placeholder: true };
}

/** Le persona est une phrase de brief : on n'en affiche qu'une etiquette lisible. */
function shorten(text, maxChars) {
  const clean = String(text).trim();
  if (clean.length <= maxChars) return clean;
  return clean.slice(0, maxChars - 1).replace(/[\s,;:]+$/, '') + '\u2026';
}

function drawtext(font, text, size, x, y, color) {
  return [
    'drawtext',
    `=fontfile=${escapeFilterValue(font)}`,
    `:text=${escapeFilterValue(text)}`,
    `:fontsize=${size}`,
    `:fontcolor=${color}`,
    `:x=${x}`,
    `:y=${y}`,
  ].join('');
}
