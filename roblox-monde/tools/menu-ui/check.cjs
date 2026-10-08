const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const [root, output] = process.argv.slice(2);
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
let suite = read('tools/menu-ui/runtime.template.luau');
for (const [key, file] of Object.entries({
  UI: 'src/client/MenuUI.luau', Layout: 'src/client/MenuLayout.luau',
  NumberFormat: 'src/shared/NumberFormat.luau', Config: 'src/shared/Config.luau', Texts: 'src/shared/Texts.luau',
  Main: 'src/client/Main.client.luau',
})) suite = suite.replace(`-- INSERT ${key}`, () => read(file));
const animals = read('src/client/Animals.luau');
const start = animals.indexOf('\tlocal equipEvent =');
const end = animals.indexOf('\t-- POSER D\'UN CLIC');
if (start < 0 || end <= start) throw new Error('Animals UI boundaries changed; update the test deliberately');
suite = suite.replace('-- INSERT AnimalsUI', () => animals.slice(start, end));
fs.writeFileSync(path.join(output, 'runtime.luau'), suite);
const result = spawnSync('luau', [path.join(output, 'runtime.luau')], { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
for (const line of result.stdout.split('\n')) {
  if (line.startsWith('SNAPSHOT:')) {
    const snapshot = JSON.parse(line.slice(9));
    fs.writeFileSync(path.join(output, `${snapshot.name}.json`), JSON.stringify(snapshot));
  } else if (line.trim()) console.log(line);
}
if (result.stderr) console.error(result.stderr);
process.exit(result.status ?? 1);
