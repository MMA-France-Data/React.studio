import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs/promises';
import { makeSampleSource } from '../examples/sample-source.js';
import { loadConfig } from '../src/config.js';
import { render } from '../src/pipeline.js';
import { probe } from '../src/lib/ffmpeg.js';

/**
 * Deroule le pipeline complet avec les providers de secours : aucune cle API,
 * aucun appel reseau. Verifie que le fichier de sortie est bien un 9:16 de la
 * duree de la source, avec une piste audio.
 */
test('pipeline complet, providers de secours', async () => {
  const outDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rs-smoke-'));

  try {
    const source = await makeSampleSource(outDir);
    const config = loadConfig({ 'vision.provider': 'stub', 'avatar.provider': 'placeholder' });

    const result = await render({ source, outDir, config });

    const output = await probe(result.outFile);
    assert.equal(output.width, 1080);
    assert.equal(output.height, 1920);
    assert.ok(output.hasAudio, 'la video de sortie doit porter une piste audio');
    assert.ok(Math.abs(output.duration - 12) < 0.5, `duree inattendue : ${output.duration}`);

    const srt = await fs.readFile(result.srtFile, 'utf8');
    assert.ok(srt.includes('-->'), 'le SRT doit contenir des timings');
    assert.ok(result.script.beats.length >= 2);
  } finally {
    await fs.rm(outDir, { recursive: true, force: true });
  }
});
