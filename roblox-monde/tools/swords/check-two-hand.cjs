const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),os=require('node:os'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),asset=path.join(root,'assets/combat/hyena-two-hand');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const xml=read('assets/combat/hyena-two-hand/R15Preview.rbxmx');
function field(p,type,name){const s=p.match(new RegExp('<'+type+' name="'+name+'">([\\s\\S]*?)</'+type+'>'));assert(s,'Rig property '+name);return s[1]}
function matrix(p,name){const raw=field(p,'CoordinateFrame',name);return ['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'].map(k=>Number(raw.match(new RegExp('<'+k+'>([^<]+)</'+k+'>'))[1]))}
const names=new Map([...xml.matchAll(/<Item class="Part" referent="([^"]+)"><Properties>([\s\S]*?)<\/Properties><\/Item>/g)].map(([,ref,p])=>[ref,field(p,'string','Name')]));
const rig=[...xml.matchAll(/<Item class="Motor6D"[^>]*><Properties>([\s\S]*?)<\/Properties><\/Item>/g)].map(([,p])=>({name:field(p,'string','Name')==='Core'?'Root':field(p,'string','Name'),parent:names.get(field(p,'Ref','Part0')),child:names.get(field(p,'Ref','Part1')),c0:matrix(p,'C0'),c1:matrix(p,'C1')}));
assert.equal(rig.length,15);assert(rig.every(j=>j.parent&&j.child));
for(const name of ['Idle','SlashRight','SlashLeft']){
 const clip=fs.readFileSync(path.join(asset,name+'.rbxmx'),'utf8');
 assert.equal([...clip.matchAll(/class="KeyframeSequence"/g)].length,1);
 assert(clip.includes('<string name="Name">HumanoidRootPart</string>'));
 assert.equal([...clip.matchAll(/<string name="Name">Impact<\/string>/g)].length,name==='Idle'?0:1);
 assert(clip.includes('<bool name="Loop">'+(name==='Idle')+'</bool>'));
 const duration=Math.max(...[...clip.matchAll(/<float name="Time">([^<]+)<\/float>/g)].map(m=>Number(m[1])));
 assert(Math.abs(duration-(name==='Idle'?2:.38))<1e-9);
}
const literal=v=>Array.isArray(v)?'{'+v.map(literal).join(',')+'}':typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'["'+k+'"]='+literal(x)).join(',')+'}':JSON.stringify(v);
let fixture=read('tools/swords/two-hand-runtime.template.luau').replace('--[[RIG_DATA]]',literal(rig));
fixture=fixture.replace('--[[PATH_SOURCE]]',read('src/client/TwoHandSwordPath.luau'))
 .replace('--[[MOTION_SOURCE]]',read('src/client/TwoHandSwordMotion.luau').replace('local Path = require(script.Parent.TwoHandSwordPath)','local Path = Path'))
 .replace('--[[COMBAT_SOURCE]]',read('src/client/CombatMotion.luau'))
 .replace('--[[GRIP_SOURCE]]',read('src/client/SwordGrip.luau'));
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'hyena-two-hand-')),file=path.join(temp,'contract.luau');fs.writeFileSync(file,fixture);
const result=cp.spawnSync('luau',[file],{encoding:'utf8'});process.stdout.write(result.stdout);process.stderr.write(result.stderr);assert.equal(result.status,0,'Runtime FK contract failed');
console.log('HYENA_NATIVE_CLIPS_OK idle + two cuts, one Impact each, original .38s timing');
