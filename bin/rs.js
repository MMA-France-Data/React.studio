#!/usr/bin/env node
import path from 'node:path';
import { loadConfig } from '../src/config.js';
import { render, DEFAULT_PERSONA } from '../src/pipeline.js';
import { inspectSource } from '../src/steps/ingest.js';
import { analyze } from '../src/steps/analyze.js';
import { ensureDir, slugify } from '../src/lib/fsx.js';
import { log } from '../src/lib/log.js';

const USAGE = `reaction-studio - videos TikTok 9:16 « reaction »

  rs render <video>     monte la video complete (script + voix + personnage)
  rs script <video>     ecrit seulement le script de reaction (script.json)
  rs demo               fabrique une source de test et deroule tout le pipeline

Options
  --persona "<texte>"   qui reagit, et comment       (defaut : spectateur expressif)
  --out <fichier.mp4>   chemin de sortie
  --out-dir <dossier>   dossier de sortie             (defaut : out)
  --reactor-image <img> portrait du personnage
  --top-ratio <0.35-0.85> part de hauteur pour la video source (defaut : 0.60)
  --fps <n>             images par seconde            (defaut : 30)
  --vision <auto|claude|stub>
  --tts <auto|elevenlabs|espeak>
  --avatar <placeholder|cmd>
  --keep-work           conserve les fichiers intermediaires
  -h, --help
`;

const FLAGS = new Set(['--keep-work', '-h', '--help']);

function parseArgs(argv) {
  const options = {};
  const positional = [];

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('-')) {
      positional.push(arg);
    } else if (FLAGS.has(arg)) {
      options[arg.replace(/^-+/, '')] = true;
    } else {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        throw new Error(`L'option ${arg} attend une valeur.`);
      }
      options[arg.replace(/^--/, '')] = value;
      i += 1;
    }
  }
  return { options, positional };
}

function configFrom(options) {
  return loadConfig({
    'vision.provider': options.vision,
    'tts.provider': options.tts,
    'avatar.provider': options.avatar,
    'avatar.reactorImage': options['reactor-image'],
    'render.topRatio': options['top-ratio'] ? Number(options['top-ratio']) : undefined,
    'render.fps': options.fps ? Number(options.fps) : undefined,
  });
}

async function main() {
  const { options, positional } = parseArgs(process.argv.slice(2));
  const command = positional[0];

  if (!command || options.help || options.h) {
    console.log(USAGE);
    return;
  }

  const config = configFrom(options);
  const persona = options.persona || DEFAULT_PERSONA;
  const outDir = options['out-dir'] || 'out';

  if (command === 'demo') {
    const { makeSampleSource } = await import('../examples/sample-source.js');
    log.step('Fabrication d\'une video source de demonstration');
    const source = await makeSampleSource(outDir);
    log.ok(source);
    await render({ source, persona, outDir, keepWork: Boolean(options['keep-work']), config });
    return;
  }

  const source = positional[1];
  if (!source) throw new Error(`La commande "${command}" attend un fichier video.\n\n${USAGE}`);

  if (command === 'render') {
    await render({
      source,
      persona,
      outFile: options.out,
      outDir,
      keepWork: Boolean(options['keep-work']),
      config,
    });
    return;
  }

  if (command === 'script') {
    log.reset();
    log.step('Lecture de la video source');
    const info = await inspectSource(source);

    log.step('Ecriture du script de reaction');
    const workDir = await ensureDir(path.join(outDir, slugify(source)));
    await analyze({ source, info, workDir, persona, config });
    log.result(`Script ecrit dans ${path.join(workDir, 'script.json')}`);
    return;
  }

  throw new Error(`Commande inconnue : ${command}\n\n${USAGE}`);
}

main().catch((error) => {
  log.error(error.message);
  process.exitCode = 1;
});
