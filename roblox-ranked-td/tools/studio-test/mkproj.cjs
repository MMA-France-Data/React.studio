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
tree.ReplicatedStorage.__AutoPlayTest = { $className: 'NumberValue', $properties: { Value: Number(duration) } };
// Scénario côté serveur : map principale (HubServer) ou match ranked contre le bot (MatchServer).
const serverScenario = mode === 'match' ? 'MatchServer.luau' : 'HubServer.luau';
tree.ReplicatedStorage.__AutoTestScript = { $path: norm(path.join(here, 'scenarios', serverScenario)) };
tree.ReplicatedStorage.__AutoTestClient = { $path: norm(path.join(here, 'scenarios', 'Client.luau')) };

fs.writeFileSync(path.join(out, `${mode}.project.json`), JSON.stringify(project, null, 1));
