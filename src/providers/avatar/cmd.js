import { spawn } from 'node:child_process';
import { log } from '../../lib/log.js';

/**
 * Delegue le rendu du personnage a une commande externe : c'est le point
 * d'accroche pour brancher n'importe quel service (Hedra, D-ID, LivePortrait
 * en local, un script maison) sans toucher au pipeline.
 *
 * Placeholders remplaces dans RS_AVATAR_CMD :
 *   {audio} {image} {out} {duration} {width} {height} {persona}
 * La commande doit ecrire une video a {out}. Le montage se charge ensuite du
 * recadrage et du calage sur la duree exacte.
 */
export async function render({ voiceTrack, outFile, duration, image, cmd, width, height, persona }) {
  if (!cmd) throw new Error('RS_AVATAR_PROVIDER=cmd mais RS_AVATAR_CMD est vide.');

  const command = cmd
    .replaceAll('{audio}', quote(voiceTrack))
    .replaceAll('{image}', quote(image || ''))
    .replaceAll('{out}', quote(outFile))
    .replaceAll('{duration}', duration.toFixed(3))
    .replaceAll('{width}', String(width))
    .replaceAll('{height}', String(height))
    .replaceAll('{persona}', quote(persona || ''));

  log.detail(`commande avatar : ${command}`);
  await run(command);

  return { outFile, placeholder: false };
}

function quote(value) {
  return `'${String(value).replaceAll("'", `'\\''`)}'`;
}

function run(command) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, { shell: true, stdio: ['ignore', 'inherit', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (d) => {
      stderr += d;
      process.stderr.write(d);
    });
    child.on('error', reject);
    child.on('close', (code) => (code === 0
      ? resolve()
      : reject(new Error(`La commande avatar a echoue (code ${code})\n${stderr.trim().slice(-500)}`))));
  });
}
