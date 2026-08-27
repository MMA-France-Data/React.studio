/**
 * Sous-titres ASS generes a la taille reelle de la video : en fixant
 * PlayResX/PlayResY sur les dimensions de sortie, toutes les tailles et marges
 * sont exprimees en pixels. Un SRT passe au filtre `subtitles` serait mis a
 * l'echelle par libass depuis une resolution arbitraire, avec une taille de
 * texte imprevisible selon la version de ffmpeg.
 */
import { wrapLines } from './text.js';

export function buildAss(cues, { width, height, marginBottom, fontName = 'DejaVu Sans', fontSize, maxChars = 26 }) {
  const size = fontSize ?? Math.round(height * 0.036);

  const header = [
    '[Script Info]',
    'ScriptType: v4.00+',
    `PlayResX: ${width}`,
    `PlayResY: ${height}`,
    'WrapStyle: 0',
    'ScaledBorderAndShadow: yes',
    '',
    '[V4+ Styles]',
    'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    // Alignment 2 = bas-centre ; MarginV remonte le bloc au-dessus du personnage.
    `Style: Reaction,${fontName},${size},&H00FFFFFF,&H000000FF,&H00141414,&H96000000,-1,0,0,0,100,100,0,0,1,${Math.round(size * 0.09)},0,2,${Math.round(width * 0.07)},${Math.round(width * 0.07)},${Math.round(marginBottom)},1`,
    '',
    '[Events]',
    'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
  ];

  const sorted = [...cues].sort((a, b) => a.start - b.start);
  const events = sorted.map((cue, i) => {
    const next = sorted[i + 1];
    const end = next ? Math.min(cue.end, next.start - 0.08) : cue.end;
    // `\h` : espace insecable ASS, pour que « ? » ne saute pas seul a la ligne.
    const text = wrapLines(cue.text, maxChars, '\\h').join('\\N');
    return `Dialogue: 0,${assTime(cue.start)},${assTime(Math.max(cue.start + 0.4, end))},Reaction,,0,0,0,,${text}`;
  });

  return [...header, ...events, ''].join('\n');
}

/** `H:MM:SS.cc` — l'ASS compte en centiemes, pas en millisecondes. */
function assTime(seconds) {
  const clamped = Math.max(0, seconds);
  const cs = Math.floor((clamped % 1) * 100);
  const total = Math.floor(clamped);
  const h = Math.floor(total / 3600);
  const m = String(Math.floor((total % 3600) / 60)).padStart(2, '0');
  const s = String(total % 60).padStart(2, '0');
  return `${h}:${m}:${s}.${String(cs).padStart(2, '0')}`;
}
