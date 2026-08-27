# reaction-studio

Génère des vidéos **TikTok 9:16 « réaction »** : une vidéo source, un
personnage qui la regarde et réagit, avec des répliques écrites par IA et calées
sur les temps forts. Deux formats de cadre selon l'orientation de la source.

```
   split  (source horizontale)        pip  (source verticale)
┌───────────────────────┐         ┌───────────────────────┐
│                       │         │                       │
│     vidéo source      │         │                       │
│   (fond flou si le    │         │     vidéo source      │
│  format ne colle pas) │         │     en plein cadre    │
│                       │         │                       │
│   « Non mais il est   │         │                       │
│      sérieux là ? »   │         │   « Non mais il est   │
├───────────────────────┤         │      sérieux là ? »   │
│                       │         │   ⬤                   │
│  le personnage qui    │         │  personnage           │
│       réagit          │         │                       │
└───────────────────────┘         └───────────────────────┘
```

**Choisissez le format selon l'orientation de la source.** Une vidéo verticale
empilée se retrouve écrasée dans le tiers central du cadre : `--layout pip` lui
rend toute la surface et pose le personnage dans une bulle. Une vidéo
horizontale, elle, ne perd rien à l'empilement : `--layout split` (le défaut).

## Démarrage

Prérequis : Node.js 20+ et `ffmpeg` (avec libass, présent dans les paquets
standards). `espeak-ng` est optionnel mais recommandé pour tester sans clé API.

```bash
npm install
npm run demo                      # fabrique une source de test et déroule tout
node bin/rs.js render ma-video.mp4 --persona "chat blasé qui commente tout"
```

**Aucune clé API n'est nécessaire pour démarrer.** Sans clé, le pipeline tourne
de bout en bout avec des providers de secours : le montage, le cadrage, le
timing et les sous-titres sont réels ; seuls le texte des répliques (générique)
et le personnage (une maquette animée par la voix) sont des placeholders.
C'est fait pour valider le format avant de dépenser quoi que ce soit.

## Brancher les vrais outils

Copiez `.env.example` en `.env` et remplissez ce dont vous avez besoin. Les
trois briques sont indépendantes : vous pouvez n'en activer qu'une.

| Brique | Sans clé | Avec clé |
|---|---|---|
| **Écriture du script** | répliques génériques, calage réel | `ANTHROPIC_API_KEY` → Claude analyse les images de la vidéo et écrit les répliques |
| **Voix** | `espeak-ng`, robotique mais audible | `ELEVENLABS_API_KEY` + `ELEVENLABS_VOICE_ID` → voix réaliste |
| **Personnage** | maquette animée par l'enveloppe de la voix | `RS_AVATAR_PROVIDER=cmd` → votre service de rendu (voir [docs/PROVIDERS.md](docs/PROVIDERS.md)) |

Le personnage est volontairement branché par une commande externe plutôt que
par un client HTTP figé : les services de génération d'avatars changent d'API
souvent, et le pipeline n'a pas à en dépendre.

## Commandes

```
rs render <video>     monte la vidéo complète
rs script <video>     écrit seulement le script de réaction (script.json)
rs demo               fabrique une source de test et déroule tout le pipeline
```

Options principales :

```
--persona "<texte>"       qui réagit, et comment
--out <fichier.mp4>       chemin de sortie
--reactor-image <img>     portrait du personnage
--layout <split|pip>      format du cadre (défaut split)
--top-ratio <0.35-0.85>   split : part de hauteur pour la source (défaut 0.60)
--pip-scale <0.18-0.6>    pip : diamètre de la bulle / largeur (défaut 0.34)
--pip-position <bottom-left|bottom-right|top-left|top-right>
--vision <auto|claude|stub>
--tts <auto|elevenlabs|espeak>
--avatar <placeholder|cmd>
--keep-work               conserve les fichiers intermédiaires
```

Chaque rendu produit trois fichiers : le `.mp4`, un `.srt` (pour ré-éditer les
sous-titres ailleurs) et un `.json` avec le script, les timecodes, la légende
et les hashtags proposés.

## Comment ça marche

```
vidéo source
   ├─ ffprobe            → durée, format, présence d'audio
   ├─ détection de plans → les instants où il se passe quelque chose
   ├─ extraction d'images horodatées
   │      └─ Claude (vision) → script.json : { t, réplique, émotion, ce qui déclenche }
   ├─ TTS par réplique   → clips posés à leur timecode sur une piste voix unique
   ├─ provider avatar    → clip du personnage, piloté par la piste voix
   └─ ffmpeg (une passe) → montage 9:16 (empilement ou bulle), sous-titres ASS,
                            son source atténué sous la voix, mention
                            « contenu généré par IA »
```

Deux points qui font la différence sur ce format :

- **Le calage.** Les répliques sont posées sur des instants précis, pas
  réparties uniformément. Le modèle reçoit des images horodatées et les
  changements de plan détectés automatiquement.
- **Le ducking.** Le son de la vidéo source baisse tout seul quand le
  personnage parle (compression sidechain pilotée par la piste voix) et remonte
  dès qu'il se tait. Sans ça, on n'entend ni l'un ni l'autre.

## Structure

```
bin/rs.js                 CLI
src/pipeline.js           orchestration des étapes
src/steps/                ingest → analyze → voice → avatar → compose
src/providers/vision/     claude | stub
src/providers/tts/        elevenlabs | espeak
src/providers/avatar/     placeholder | cmd
src/lib/                  ffmpeg, ASS/SRT, config, logs
examples/providers/       exemples de commandes de rendu du personnage
```

## Tests

```bash
npm test          # unitaires : ASS/SRT, layout, normalisation du script
npm run test:smoke  # pipeline complet, sans réseau (~20 s)
```

## À savoir avant de publier

- **TikTok demande de signaler les contenus IA réalistes.** Le pipeline incruste
  une mention (`RS_AI_DISCLOSURE`) sur la vidéo ; pensez aussi à activer le
  marquage AIGC au moment de la publication.
- **Les vidéos sources ne vous appartiennent pas par défaut.** Utilisez vos
  propres rushes, des banques libres de droits, ou une autorisation explicite.
