// Génère un projet Rojo de test à partir de default.project.json, dans out/.
// Il ajoute seulement le marqueur __AutoPlayTest (durée du test) et les scénarios de test.
//   node mkproj.cjs <hub|match|tournage|phone|levels> <durée en secondes>
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
// Test « téléphone » : le tuto des nouveaux joueurs démarre tout seul, comme dans le jeu publié (dans les autres
// places de test il ne démarre jamais seul : src/client/TutorialUI.luau lit cet objet).
if (mode === 'phone') {
	tree.ReplicatedStorage.__AutoTestNewPlayer = { $className: 'BoolValue', $properties: { Value: true } };
	// ... et le joueur de test y reçoit la parcelle 2 au lieu de la 1 (src/server/Hub/Plots.luau lit cet objet),
	// comme le 2e joueur arrivé sur un serveur : le tuto doit le guider vers SA parcelle.
	tree.ReplicatedStorage.__AutoTestPlot = { $className: 'IntValue', $properties: { Value: 2 } };
}
// Test des NIVEAUX (prototype de la nouvelle formule, phone.ps1 -Mode levels) : dans les autres places de test les
// niveaux sont fermés (src/server/Hub/LevelsService.luau lit cet objet), ici ils sont ouverts au joueur de test.
if (mode === 'levels') {
	tree.ReplicatedStorage.__AutoTestLevels = { $className: 'BoolValue', $properties: { Value: true } };
}
// Scénarios serveur et client : map principale (HubServer), match ranked contre le bot (MatchServer), mode
// tournage (images et vidéos du jeu, tournage.ps1 : TournageServer et TournageClient), test « téléphone »
// (phone.ps1 : le jeu dans une fenêtre de la taille d'un téléphone, PhoneServer et PhoneClient), ou test des
// niveaux (phone.ps1 -Mode levels : LevelsServer et LevelsClient).
const scenarios = {
	hub: ['HubServer.luau', 'Client.luau'],
	match: ['MatchServer.luau', 'Client.luau'],
	tournage: ['TournageServer.luau', 'TournageClient.luau'],
	phone: ['PhoneServer.luau', 'PhoneClient.luau'],
	levels: ['LevelsServer.luau', 'LevelsClient.luau'],
};
const [serverScenario, clientScenario] = scenarios[mode] || scenarios.hub;
tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', clientScenario)) };

fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
