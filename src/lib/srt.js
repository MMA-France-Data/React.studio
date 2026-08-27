import { toSrtTime } from './time.js';

/**
 * Construit un SRT a partir des repliques.
 * Les sous-titres ne peuvent pas se chevaucher : une replique qui deborde sur
 * la suivante est tronquee pour laisser 80 ms de respiration.
 */
export function buildSrt(cues) {
  const sorted = [...cues].sort((a, b) => a.start - b.start);

  return sorted
    .map((cue, i) => {
      const next = sorted[i + 1];
      const end = next ? Math.min(cue.end, next.start - 0.08) : cue.end;
      return [
        String(i + 1),
        `${toSrtTime(cue.start)} --> ${toSrtTime(Math.max(cue.start + 0.3, end))}`,
        wrap(cue.text, 28),
        '',
      ].join('\n');
    })
    .join('\n');
}

/** Retour a la ligne sur les mots : deux lignes courtes se lisent mieux qu'une longue. */
function wrap(text, maxChars) {
  const words = text.split(/\s+/);
  const lines = [];
  let current = '';

  for (const word of words) {
    if (current && (current + ' ' + word).length > maxChars) {
      lines.push(current);
      current = word;
    } else {
      current = current ? current + ' ' + word : word;
    }
  }
  if (current) lines.push(current);
  return lines.join('\n');
}
