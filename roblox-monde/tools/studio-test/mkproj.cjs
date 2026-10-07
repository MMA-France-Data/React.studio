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
//   hunter : seulement le prédateur de la salle 2 (petit test, environ 4 minutes)
//   jump : mesure la hauteur de marche qu'un personnage peut grimper d'un saut (réglage des salles de lave)
const scenarios = {
	world: ['WorldServer.luau', 'WorldClient.luau'],
};
if (!scenarios[mode]) {
	console.error(`Test inconnu : ${mode} (attendu : ${Object.keys(scenarios).join(', ')})`);
	process.exit(1);
}

const project = JSON.parse(fs.readFileSync(path.join(repo, 'default.project.json'), 'utf8'));
const tree = project.tree;
// Le projet de test est écrit dans out/ : tous les chemins du projet (scripts, modèles de assets/) deviennent absolus.
const absolute = (node) => {
	if (!node || typeof node !== 'object') return;
	if (typeof node.$path === 'string' && !path.isAbsolute(node.$path)) node.$path = norm(path.join(repo, node.$path));
	for (const [key, child] of Object.entries(node)) if (!key.startsWith('$')) absolute(child);
};
absolute(tree);
tree.ReplicatedStorage.__AutoPlayTest = { $className: 'NumberValue', $properties: { Value: Number(duration) } };
const [serverScenario, clientScenario] = scenarios[mode];
tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', clientScenario)) };

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
