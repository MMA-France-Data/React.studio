// Génère un projet Rojo de test à partir de default.project.json, dans out/.
// Il ajoute seulement le marqueur __AutoPlayTest (durée du test) et les scénarios de test.
//   node mkproj.cjs <levels|monsters|tutorial|english> <durée en secondes>
const fs = require('fs');
const path = require('path');

const [mode, duration] = process.argv.slice(2);
const here = __dirname;
const repo = path.resolve(here, '..', '..');
const out = path.join(here, 'out');
const norm = (p) => p.split(path.sep).join('/');

// Scénarios (dossier scenarios) : [serveur, client]. null = pas de scénario de ce côté.
//   levels   : le jeu en entier (niveaux, camp d'entraînement, interface à la taille d'un ordinateur puis d'un téléphone)
//   monsters : les modèles 3D des monstres (assets/EnemyModels) et la galerie Studio
//   tutorial : le tuto d'un nouveau joueur (la flèche de TutorialUI), du camp à la boutique
//   english  : la version anglaise : tous les écrans passés en anglais, aucun texte ne doit rester en français
const scenarios = {
	levels: ['LevelsServer.luau', 'LevelsClient.luau'],
	monsters: [null, 'MonstersClient.luau'],
	tutorial: ['TutorialServer.luau', 'TutorialClient.luau'],
	english: ['EnglishServer.luau', 'EnglishClient.luau'],
};
if (!scenarios[mode]) {
	console.error(`Test inconnu : ${mode} (attendu : ${Object.keys(scenarios).join(', ')})`);
	process.exit(1);
}

const project = JSON.parse(fs.readFileSync(path.join(repo, 'default.project.json'), 'utf8'));
const tree = project.tree;
tree.ReplicatedStorage.Shared.$path = norm(path.join(repo, 'src', 'shared'));
tree.ServerScriptService.Server.$path = norm(path.join(repo, 'src', 'server'));
tree.StarterPlayer.StarterPlayerScripts.Client.$path = norm(path.join(repo, 'src', 'client'));
// Modèles perso des monstres (assets/EnemyModels) : chemin relatif au dépôt, à rendre absolu lui aussi
// (le projet de test est écrit dans out/).
const enemyModels = tree.ReplicatedStorage.EnemyModels;
if (enemyModels && enemyModels.$path && !path.isAbsolute(enemyModels.$path)) {
	enemyModels.$path = norm(path.join(repo, enemyModels.$path));
}
tree.ReplicatedStorage.__AutoPlayTest = { $className: 'NumberValue', $properties: { Value: Number(duration) } };
// Les tests automatiques se jouent sans le tuto (TutorialUI ne démarre pas), sauf celui du tuto et celui de la
// version anglaise (les mots de la flèche sont traduits aussi) : ce marqueur le laisse démarrer, comme pour un
// vrai nouveau joueur.
if (mode === 'tutorial' || mode === 'english') {
	tree.ReplicatedStorage.__AutoTestNewPlayer = { $className: 'BoolValue', $properties: { Value: true } };
}
const [serverScenario, clientScenario] = scenarios[mode];
if (serverScenario) {
	tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
}
if (clientScenario) {
	tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', clientScenario)) };
}

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
