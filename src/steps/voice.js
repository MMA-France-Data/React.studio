import path from 'node:path';
import { ffmpeg, audioDuration } from '../lib/ffmpeg.js';
import { ffSeconds } from '../lib/time.js';
import { ensureDir } from '../lib/fsx.js';
import { log } from '../lib/log.js';

/**
 * Synthetise chaque replique, puis assemble une piste voix unique de la
 * longueur exacte de la video, chaque clip pose a son timecode.
 * Renvoie aussi les bornes reelles de chaque replique : les sous-titres et le
 * ducking s'appuient sur la duree mesuree, pas sur l'estimation du script.
 */
export async function synthesizeVoice({ script, duration, workDir, config }) {
  const dir = await ensureDir(path.join(workDir, 'voice'));
  const provider = await resolveTtsProvider(config);
  log.detail(`voix : ${provider.name}`);

  const clips = [];
  let silentCount = 0;

  for (const [index, beat] of script.beats.entries()) {
    const file = path.join(dir, `beat${String(index).padStart(2, '0')}.wav`);
    const result = await provider.synthesize({
      text: beat.line,
      outFile: file,
      lang: config.lang,
      fallbackDuration: beat.estimatedDuration,
      config,
    });

    if (result.silent) silentCount += 1;
    const clipDuration = await audioDuration(file);
    clips.push({ ...beat, file, start: beat.t, end: beat.t + clipDuration, duration: clipDuration });
  }

  if (silentCount) {
    log.warn(`${silentCount} replique(s) sans voix : ni ElevenLabs ni espeak-ng n'etaient disponibles.`);
  }

  const overflow = clips.filter((clip) => clip.end > duration);
  if (overflow.length) {
    log.warn(`${overflow.length} replique(s) depassent la fin de la video et seront coupees au montage.`);
  }

  const voiceTrack = path.join(workDir, 'voice.wav');
  await mixTrack(clips, voiceTrack, duration);
  log.ok(`piste voix : ${clips.length} clips, ${duration.toFixed(2)}s`);

  return { voiceTrack, clips };
}

/** Pose chaque clip a son offset et remplit le reste de silence. */
async function mixTrack(clips, outFile, duration) {
  if (!clips.length) {
    await ffmpeg([
      '-f', 'lavfi', '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
      '-t', ffSeconds(duration), '-c:a', 'pcm_s16le', outFile,
    ], 'piste voix vide');
    return;
  }

  const inputs = clips.flatMap((clip) => ['-i', clip.file]);
  const delays = clips.map((clip, i) => `[${i}:a]adelay=${Math.round(clip.start * 1000)}:all=1[d${i}]`);
  const labels = clips.map((_, i) => `[d${i}]`).join('');

  const filter = [
    ...delays,
    `${labels}amix=inputs=${clips.length}:normalize=0:dropout_transition=0[mixed]`,
    `[mixed]apad,atrim=0:${ffSeconds(duration)},asetpts=N/SR/TB[out]`,
  ].join(';');

  await ffmpeg([
    ...inputs,
    '-filter_complex', filter,
    '-map', '[out]',
    '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le',
    outFile,
  ], 'assemblage de la piste voix');
}

async function resolveTtsProvider(config) {
  const wanted = config.tts.provider;
  const hasKey = Boolean(config.tts.apiKey && config.tts.voiceId);

  if (wanted === 'elevenlabs' || (wanted === 'auto' && hasKey)) {
    const mod = await import('../providers/tts/elevenlabs.js');
    return { name: 'elevenlabs', synthesize: mod.synthesize };
  }

  const mod = await import('../providers/tts/espeak.js');
  const available = await mod.isAvailable();
  return { name: available ? 'espeak-ng (secours)' : 'aucun (silence)', synthesize: mod.synthesize };
}
