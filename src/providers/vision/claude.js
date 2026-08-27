import fs from 'node:fs/promises';
import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { ScriptSchema } from './schema.js';
import { log } from '../../lib/log.js';

const SYSTEM = `Tu ecris les repliques d'un personnage qui regarde une video et reagit, pour TikTok.

Format de la video finale : la video source en haut, le personnage en bas. Le
spectateur voit les deux en meme temps, donc tes repliques commentent ce qui est
visible a l'instant meme.

Regles d'ecriture :
- Francais parle, oral, comme quelqu'un qui reagit a voix haute devant son ecran.
- Chaque replique tient en 12 mots maximum. Une idee par replique.
- Ne decris jamais l'image ("on voit un chat qui..."). Reagis-y.
- Cale chaque replique sur un instant precis : juste avant le temps fort pour
  l'anticipation, juste apres pour la punchline.
- Laisse respirer. Trois a cinq repliques sur un clip court valent mieux qu'un
  commentaire continu.
- Pas d'emoji dans les repliques : elles sont dites a voix haute.
- La premiere replique doit tomber dans la premiere seconde et donner envie de
  rester.`;

/**
 * Ecrit le script de reaction a partir d'images horodatees de la video source.
 * Chaque image est precedee de son timecode pour que le modele puisse caler
 * les repliques sur les temps forts.
 */
export async function writeScript({ frames, duration, sceneChanges, persona, config }) {
  const client = new Anthropic(config.vision.apiKey ? { apiKey: config.vision.apiKey } : {});

  const content = [];
  content.push({
    type: 'text',
    text: buildBrief({ duration, sceneChanges, persona, frameCount: frames.length }),
  });

  for (const frame of frames) {
    content.push({ type: 'text', text: `t = ${frame.t.toFixed(2)}s` });
    content.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: 'image/jpeg',
        data: (await fs.readFile(frame.file)).toString('base64'),
      },
    });
  }

  log.detail(`${config.vision.model} - ${frames.length} images - effort ${config.vision.effort}`);

  const response = await client.messages.parse({
    model: config.vision.model,
    max_tokens: 8000,
    system: SYSTEM,
    thinking: { type: 'adaptive' },
    output_config: {
      effort: config.vision.effort,
      format: zodOutputFormat(ScriptSchema),
    },
    messages: [{ role: 'user', content }],
  });

  if (response.stop_reason === 'refusal') {
    throw new Error(`Le modele a decline la demande (${response.stop_details?.category ?? 'sans categorie'}).`);
  }
  if (!response.parsed_output) {
    throw new Error("Le modele n'a pas renvoye de script exploitable.");
  }

  return { ...response.parsed_output, source: 'claude' };
}

function buildBrief({ duration, sceneChanges, persona, frameCount }) {
  const cuts = sceneChanges.length
    ? `Changements visuels marques detectes automatiquement (secondes) : ${sceneChanges.map((t) => t.toFixed(2)).join(', ')}. Sers-t'en pour caler les repliques, mais fie-toi surtout aux images.`
    : "Aucun changement de plan marque n'a ete detecte : les temps forts sont dans le mouvement, a toi de les reperer sur les images.";

  return `Voici ${frameCount} images extraites d'une video de ${duration.toFixed(2)} secondes, dans l'ordre chronologique et horodatees.

${cuts}

Personnage qui reagit : ${persona}

Ecris le script de reaction. Toutes les valeurs de t doivent etre comprises entre 0 et ${duration.toFixed(2)}, dans l'ordre croissant, et espacees d'au moins 1,2 seconde.`;
}
