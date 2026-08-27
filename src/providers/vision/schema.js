import { z } from 'zod';

export const EMOTIONS = [
  'choc', 'rire', 'tendresse', 'agacement', 'admiration', 'peur', 'curiosite',
];

export const BeatSchema = z.object({
  t: z.number().describe('Timecode en secondes, au moment ou la replique doit commencer.'),
  line: z.string().describe('La replique, en francais parle, 12 mots maximum.'),
  emotion: z.enum(EMOTIONS).describe('Emotion jouee par le personnage sur cette replique.'),
  cue: z.string().describe('Ce qui se passe a l ecran a cet instant et qui declenche la reaction.'),
});

export const ScriptSchema = z.object({
  summary: z.string().describe('Une phrase : ce que montre la video source.'),
  hook: z.string().describe('Phrase d accroche des la premiere seconde, 8 mots maximum.'),
  beats: z.array(BeatSchema).describe('Les reactions, dans l ordre chronologique.'),
  caption: z.string().describe('Legende du post TikTok.'),
  hashtags: z.array(z.string()).describe('Hashtags sans le caractere diese.'),
});
