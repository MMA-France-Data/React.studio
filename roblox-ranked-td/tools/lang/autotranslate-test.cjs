// Teste src/client/AutoTranslate.luau sans Studio (depuis le dossier roblox-ranked-td) :
//   node tools/lang/autotranslate-test.cjs
// Colle le faux Roblox (autotranslate-mock.luau), les vraies sources (Lang.luau, AutoTranslate.luau, Glossaire) et
// les tests (autotranslate-tests.luau) dans tools/lang/out/autotranslate.luau, puis le lance 4 fois avec luau :
// événements immédiats ou différés (Workspace.SignalBehavior), joueur français qui passe en anglais, ou joueur anglais
// dès le départ. Sortie 1 si un test rate. Il faut luau (luau.exe) dans le PATH.
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const here = __dirname;
const repo = path.resolve(here, "..", "..");
const read = (file) => fs.readFileSync(file, "utf8");
const sources = {
  Lang: read(path.join(repo, "src", "shared", "Lang.luau")),
  AutoTranslate: read(path.join(repo, "src", "client", "AutoTranslate.luau")),
  Glossary: read(path.join(repo, "src", "shared", "LangEN", "Glossary.luau")),
};
let block = "";
const eq = "=".repeat(8);
for (const [name, source] of Object.entries(sources)) {
  if (source.includes(`]${eq}]`)) throw new Error("délimiteur présent dans " + name);
  block += `SOURCES.${name} = [${eq}[\n${source}]${eq}]\n`;
}
const harness = read(path.join(here, "autotranslate-mock.luau"))
  .replace("--@@SOURCES@@", () => block)
  .replace("--@@TESTS@@", () => read(path.join(here, "autotranslate-tests.luau")));
const outDir = path.join(here, "out");
fs.mkdirSync(outDir, { recursive: true });
const file = path.join(outDir, "autotranslate.luau");
fs.writeFileSync(file, harness);

let failed = false;
for (const mode of ["immediate", "deferred"]) {
  for (const language of ["fr", "en"]) {
    const run = spawnSync("luau", [file, "-a", mode, language], { encoding: "utf8" });
    if (run.error) {
      console.log("luau introuvable (il doit être dans le PATH) : " + run.error.message);
      process.exit(1);
    }
    process.stdout.write(run.stdout + run.stderr);
    if (run.status !== 0) failed = true;
  }
}
console.log(failed ? "AutoTranslate : des tests ont raté" : "AutoTranslate : tous les tests réussis");
process.exit(failed ? 1 : 0);
