import fs from 'node:fs';
import path from 'node:path';

/** Charge `.env` sans dependance : `CLE=valeur`, `#` en commentaire. */
function loadDotEnv(cwd = process.cwd()) {
  const file = path.join(cwd, '.env');
  if (!fs.existsSync(file)) return;

  for (const rawLine of fs.readFileSync(file, 'utf8').split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    const eq = line.indexOf('=');
    if (eq === -1) continue;

    const key = line.slice(0, eq).trim();
    // Les valeurs deja presentes dans l'environnement gagnent sur le fichier.
    if (key in process.env) continue;

    let value = line.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

const str = (key, fallback) => (process.env[key] || '').trim() || fallback;
const num = (key, fallback) => {
  const value = Number(process.env[key]);
  return Number.isFinite(value) ? value : fallback;
};

export function loadConfig(overrides = {}) {
  loadDotEnv();

  const config = {
    lang: str('RS_LANG', 'fr'),

    vision: {
      provider: str('RS_VISION_PROVIDER', 'auto'),
      model: str('RS_VISION_MODEL', 'claude-opus-5'),
      effort: str('RS_VISION_EFFORT', 'high'),
      apiKey: str('ANTHROPIC_API_KEY', ''),
      maxFrames: num('RS_VISION_MAX_FRAMES', 20),
    },

    tts: {
      provider: str('RS_TTS_PROVIDER', 'auto'),
      apiKey: str('ELEVENLABS_API_KEY', ''),
      voiceId: str('ELEVENLABS_VOICE_ID', ''),
      modelId: str('ELEVENLABS_MODEL_ID', 'eleven_multilingual_v2'),
    },

    avatar: {
      provider: str('RS_AVATAR_PROVIDER', 'placeholder'),
      reactorImage: str('RS_REACTOR_IMAGE', ''),
      cmd: str('RS_AVATAR_CMD', ''),
    },

    render: {
      width: num('RS_WIDTH', 1080),
      height: num('RS_HEIGHT', 1920),
      fps: num('RS_FPS', 30),
      topRatio: num('RS_TOP_RATIO', 0.6),
      disclosure: str('RS_AI_DISCLOSURE', 'Contenu genere par IA'),
      font: str('RS_FONT', findFont()),
    },
  };

  return applyOverrides(config, overrides);
}

/** Les options CLI ecrasent l'environnement, qui ecrase les valeurs par defaut. */
function applyOverrides(config, overrides) {
  for (const [key, value] of Object.entries(overrides)) {
    if (value === undefined || value === null || value === '') continue;
    const parts = key.split('.');
    let node = config;
    while (parts.length > 1) node = node[parts.shift()];
    node[parts[0]] = value;
  }
  return config;
}

const FONT_CANDIDATES = [
  '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  '/System/Library/Fonts/Helvetica.ttc',
  'C:\\Windows\\Fonts\\arialbd.ttf',
];

function findFont() {
  return FONT_CANDIDATES.find((file) => fs.existsSync(file)) || '';
}
