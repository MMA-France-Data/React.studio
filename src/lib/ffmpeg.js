import { spawn } from 'node:child_process';
import { log } from './log.js';

/** Lance un binaire et resout avec stdout, ou rejette avec les dernieres lignes de stderr. */
function run(bin, args, { captureStdout = false } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, { stdio: ['ignore', captureStdout ? 'pipe' : 'ignore', 'pipe'] });
    let stdout = '';
    let stderr = '';

    if (captureStdout) child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });

    child.on('error', (err) => {
      reject(err.code === 'ENOENT'
        ? new Error(`${bin} est introuvable. Installez ffmpeg (apt install ffmpeg / brew install ffmpeg).`)
        : err);
    });

    child.on('close', (code) => {
      if (code === 0) return resolve(stdout);
      const tail = stderr.trim().split('\n').slice(-12).join('\n');
      reject(new Error(`${bin} a echoue (code ${code})\n${tail}`));
    });
  });
}

export async function ffmpeg(args, label) {
  if (label) log.detail(`ffmpeg: ${label}`);
  return run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
}

export async function ffprobeJson(file) {
  const out = await run('ffprobe', [
    '-v', 'error',
    '-print_format', 'json',
    '-show_format',
    '-show_streams',
    file,
  ], { captureStdout: true });
  return JSON.parse(out);
}

/** Metadonnees utiles d'un media : duree, dimensions, fps, presence d'audio. */
export async function probe(file) {
  const data = await ffprobeJson(file);
  const video = data.streams.find((s) => s.codec_type === 'video');
  const audio = data.streams.find((s) => s.codec_type === 'audio');
  const duration = Number(data.format?.duration ?? video?.duration ?? 0);

  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error(`Impossible de lire la duree de ${file}`);
  }

  return {
    duration,
    hasAudio: Boolean(audio),
    hasVideo: Boolean(video),
    width: video ? Number(video.width) : 0,
    height: video ? Number(video.height) : 0,
    fps: video ? parseFrameRate(video.avg_frame_rate || video.r_frame_rate) : 0,
  };
}

function parseFrameRate(value) {
  if (!value) return 0;
  const [num, den] = value.split('/').map(Number);
  return den ? num / den : num;
}

/** Duree d'un fichier audio, en secondes. */
export async function audioDuration(file) {
  const { duration } = await probe(file);
  return duration;
}

/** Echappe une valeur destinee a un filtre ffmpeg (drawtext, subtitles, ...). */
export function escapeFilterValue(value) {
  return String(value)
    .replace(/\\/g, '\\\\')
    .replace(/:/g, '\\:')
    .replace(/'/g, "\\'")
    .replace(/,/g, '\\,')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]');
}
