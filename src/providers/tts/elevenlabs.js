import fs from 'node:fs/promises';
import { ffmpeg } from '../../lib/ffmpeg.js';

const BASE = process.env.RS_ELEVENLABS_BASE || 'https://api.elevenlabs.io/v1';

/**
 * Voix realiste. `voice_settings` est volontairement plus expressif que le
 * defaut : une reaction plate ne fonctionne pas sur ce format.
 */
export async function synthesize({ text, outFile, config }) {
  const { apiKey, voiceId, modelId } = config.tts;
  if (!apiKey) throw new Error('ELEVENLABS_API_KEY est vide.');
  if (!voiceId) throw new Error('ELEVENLABS_VOICE_ID est vide (choisissez une voix dans votre compte).');

  const response = await fetch(`${BASE}/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_44100_128`, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'content-type': 'application/json',
      accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: modelId,
      voice_settings: { stability: 0.4, similarity_boost: 0.75, style: 0.5, use_speaker_boost: true },
    }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`ElevenLabs ${response.status}: ${detail.slice(0, 300)}`);
  }

  const mp3 = outFile.replace(/\.wav$/, '.mp3');
  await fs.writeFile(mp3, Buffer.from(await response.arrayBuffer()));
  await ffmpeg(['-i', mp3, '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', outFile]);

  return { outFile, silent: false };
}
