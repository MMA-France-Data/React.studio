// Génère un projet Rojo de test à partir de default.project.json, dans out/.
// Il ajoute seulement le marqueur __AutoPlayTest (durée du test) et les scénarios de test.
//   node mkproj.cjs <hub|match> <durée en secondes>
const fs = require('fs');
const path = require('path');

const [mode, duration] = process.argv.slice(2);
const here = __dirname;
const repo = path.resolve(here, '..', '..');
const out = path.join(here, 'out');
const norm = (p) => p.split(path.sep).join('/');

const project = JSON.parse(fs.readFileSync(path.join(repo, 'default.project.json'), 'utf8'));
const tree = project.tree;
// En mode match, Shared vient d'une copie où Config.STUDIO_FORCE_MODE = "Match" (faite par build.ps1).
tree.ReplicatedStorage.Shared.$path = norm(mode === 'match' ? path.join(out, 'shared_match') : path.join(repo, 'src', 'shared'));
tree.ServerScriptService.Server.$path = norm(path.join(repo, 'src', 'server'));
tree.StarterPlayer.StarterPlayerScripts.Client.$path = norm(path.join(repo, 'src', 'client'));
// Modèles perso des ennemis (assets/EnemyModels) : chemin relatif au dépôt, à rendre absolu lui aussi
// (le projet de test est écrit dans out/).
const enemyModels = tree.ReplicatedStorage.EnemyModels;
if (enemyModels && enemyModels.$path && !path.isAbsolute(enemyModels.$path)) {
	enemyModels.$path = norm(path.join(repo, enemyModels.$path));
}
tree.ReplicatedStorage.__AutoPlayTest = { $className: 'NumberValue', $properties: { Value: Number(duration) } };
// Scénarios serveur et client : map principale (HubServer), match ranked contre le bot (MatchServer), ou mode
// tournage (images et vidéos du jeu, tournage.ps1 : TournageServer et TournageClient).
const scenarios = {
	hub: ['HubServer.luau', 'Client.luau'],
	match: ['MatchServer.luau', 'Client.luau'],
	tournage: ['TournageServer.luau', 'TournageClient.luau'],
};
const [serverScenario, clientScenario] = scenarios[mode] || scenarios.hub;
tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', clientScenario)) };

fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
