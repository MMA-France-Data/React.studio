import { spawn } from 'node:child_process';
import { ffmpeg } from '../../lib/ffmpeg.js';
import { ffSeconds } from '../../lib/time.js';

let availability = null;

/** espeak-ng est installe ? Teste une seule fois par execution. */
export async function isAvailable() {
  if (availability !== null) return availability;

  availability = await new Promise((resolve) => {
    const child = spawn('espeak-ng', ['--version'], { stdio: 'ignore' });
    child.on('error', () => resolve(false));
    child.on('close', (code) => resolve(code === 0));
  });
  return availability;
}

/**
 * Voix de secours, robotique mais reelle : elle dit les vrais mots, donc le
 * calage et la longueur des repliques sont representatifs du rendu final.
 */
export async function synthesize({ text, outFile, lang = 'fr', fallbackDuration = 1.5 }) {
  if (!(await isAvailable())) {
    // Sans espeak-ng, on pose un silence de la bonne longueur : le montage
    // reste juste, seule la voix manque.
    await ffmpeg([
      '-f', 'lavfi',
      '-i', `anullsrc=channel_layout=mono:sample_rate=48000`,
      '-t', ffSeconds(fallbackDuration),
      '-c:a', 'pcm_s16le',
      outFile,
    ]);
    return { outFile, silent: true };
  }

  const raw = outFile.replace(/\.wav$/, '.espeak.wav');
  await runEspeak(['-v', lang, '-s', '158', '-p', '42', '-w', raw, text]);

  // espeak sort du 22 kHz : on normalise sur le format de travail du pipeline.
  await ffmpeg(['-i', raw, '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', outFile]);
  return { outFile, silent: false };
}

function runEspeak(args) {
  return new Promise((resolve, reject) => {
    const child = spawn('espeak-ng', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('error', reject);
    child.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`espeak-ng: ${stderr.trim()}`))));
  });
}
