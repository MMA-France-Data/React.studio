/** Ponctuation double francaise : elle ne doit jamais commencer une ligne. */
const DOUBLE_PUNCTUATION = /[  ]+([?!:;»])/g;

/**
 * Decoupe une replique en lignes courtes. Deux lignes de 20 signes se lisent
 * en une fixation ; une ligne de 40 oblige l'oeil a balayer, et sur un format
 * vertical le spectateur n'a pas ce temps-la.
 *
 * `hardSpace` est le caractere qui remplace l'espace avant `? ! : ;` : `\h`
 * en ASS, une espace insecable partout ailleurs. Sans lui, le point
 * d'interrogation se retrouve seul sur la ligne suivante.
 */
export function wrapLines(text, maxChars, hardSpace = ' ') {
  const clean = String(text)
    .replace(/[{}\\]/g, '')
    .trim()
    .replace(DOUBLE_PUNCTUATION, `${hardSpace}$1`);

  const words = clean.split(/[ \t\n]+/).filter(Boolean);
  const lines = [];
  let current = '';

  for (const word of words) {
    if (current && visualLength(current + ' ' + word, hardSpace) > maxChars) {
      lines.push(current);
      current = word;
    } else {
      current = current ? current + ' ' + word : word;
    }
  }
  if (current) lines.push(current);
  return lines;
}

/** `\h` compte pour un caractere a l'ecran, pas pour deux. */
function visualLength(text, hardSpace) {
  return hardSpace.length > 1
    ? text.split(hardSpace).join(' ').length
    : text.length;
}
