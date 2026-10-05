// Génère un projet Rojo de test à partir de default.project.json, dans out/.
// Il ajoute seulement le marqueur __AutoPlayTest (durée du test) et les scénarios de test.
//   node mkproj.cjs <game|jump> <durée en secondes>
const fs = require('fs');
const path = require('path');

const [mode, duration] = process.argv.slice(2);
const here = __dirname;
const repo = path.resolve(here, '..', '..');
const out = path.join(here, 'out');
const norm = (p) => p.split(path.sep).join('/');

// Scénarios (dossier scenarios) : [serveur, client].
//   game : tout le jeu (décor, salle de sport, les 10 salles, pièces, raccourci), avec des captures
//   jump : mesure la hauteur de marche qu'un personnage peut grimper d'un saut (réglage des salles de lave)
const scenarios = {
	game: ['GameServer.luau', 'GameClient.luau'],
	jump: ['JumpServer.luau', 'JumpClient.luau'],
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
tree.ReplicatedStorage.__AutoPlayTest = { $className: 'NumberValue', $properties: { Value: Number(duration) } };
const [serverScenario, clientScenario] = scenarios[mode];
tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', clientScenario)) };

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
