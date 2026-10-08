// Read-only FK check of the CURRENT production clip table and preview R15 rig.
// No stale generated pose data, fixed frame, Studio, or external dependency.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const dual = fs.readFileSync(path.join(root, 'src/client/DualSwordMotion.luau'), 'utf8');
const sourceName = dual.match(/Dual\.sourceClip\s*=\s*"([^"]+)"/)[1];
assert(dual.includes('motion.sample(Dual.sourceClip, elapsed)'));
const source = fs.readFileSync(path.join(root, 'src/client/CombatMotion.luau'), 'utf8');
const text = source.match(/local CLIPS = ([\s\S]*?)\r?\nlocal ORDER/)[1];
let cursor = 0;
function token(value) {
  while (/\s/.test(text[cursor] || '') && cursor < text.length) cursor++;
  if (value && text.slice(cursor, cursor + value.length) !== value) throw new Error('Unexpected table token at ' + cursor);
  if (value) cursor += value.length;
}
function table() {
  token('{');
  const array = [], object = {};
  let keyed = false;
  while (true) {
    token();
    if (text[cursor] === '}') { cursor++; return keyed ? object : array; }
    let key;
    if (text[cursor] === '[') {
      keyed = true; token('['); token();
      const match = text.slice(cursor).match(/^"(?:[^"\\]|\\.)*"/);
      assert(match, 'Only quoted keys in the generated clip table');
      key = JSON.parse(match[0]); cursor += match[0].length; token(']'); token('=');
    }
    token();
    let value;
    if (text[cursor] === '{') value = table();
    else if (text[cursor] === '"') {
      const match = text.slice(cursor).match(/^"(?:[^"\\]|\\.)*"/);
      value = JSON.parse(match[0]); cursor += match[0].length;
    } else {
      const match = text.slice(cursor).match(/^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/);
      assert(match, 'Only numerical pose values');
      value = Number(match[0]); cursor += match[0].length;
    }
    if (key !== undefined) object[key] = value; else array.push(value);
    token();
    if (text[cursor] === ',') cursor++;
    else assert.equal(text[cursor], '}');
  }
}
const clips = table();
token(); assert.equal(cursor, text.length);
const I = [0,0,0, 1,0,0, 0,1,0, 0,0,1];
function mul(a,b) {
  const c = I.slice();
  for (let i=0; i<3; i++) {
    c[i] = a[i] + [0,1,2].reduce((s,k) => s + a[3+i*3+k]*b[k], 0);
    for (let j=0; j<3; j++) c[3+i*3+j] = [0,1,2].reduce((s,k) => s + a[3+i*3+k]*b[3+k*3+j], 0);
  }
  return c;
}
function inv(a) {
  const c = I.slice();
  for (let i=0; i<3; i++) for (let j=0; j<3; j++) c[3+i*3+j] = a[3+j*3+i];
  for (let i=0; i<3; i++) c[i] = -[0,1,2].reduce((s,k) => s + c[3+i*3+k]*a[k], 0);
  return c;
}
function cf(p=[0,0,0], r=[0,0,0]) {
  const [x,y,z]=r,cx=Math.cos(x),sx=Math.sin(x),cy=Math.cos(y),sy=Math.sin(y),cz=Math.cos(z),sz=Math.sin(z);
  return [...p,cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy];
}
const mirror = v => [-v[0],v[1],v[2],v[3],-v[4],-v[5],-v[6],v[7],v[8],-v[9],v[10],v[11]];
const mirrorName = n => n.startsWith('Right') ? 'Left'+n.slice(5) : n.startsWith('Left') ? 'Right'+n.slice(4) : n;
const xml = fs.readFileSync(path.join(root, 'assets/combat/personnage-v4/models/R15Preview.rbxmx'), 'utf8');
function field(properties, type, name) {
  const match = properties.match(new RegExp('<'+type+' name="'+name+'">([\\s\\S]*?)</'+type+'>'));
  assert(match, 'Missing rig property ' + name);
  return match[1];
}
function matrix(properties, name) {
  const raw = field(properties, 'CoordinateFrame', name);
  return ['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'].map(n => Number(raw.match(new RegExp('<'+n+'>([^<]+)</'+n+'>'))[1]));
}
const joints = [...xml.matchAll(/<Item class="Motor6D"[^>]*><Properties>([\s\S]*?)<\/Properties><\/Item>/g)].map(([,p]) => ({
  name: field(p,'string','Name'), parent: field(p,'Ref','Part0'), child: field(p,'Ref','Part1'), c0: matrix(p,'C0'), c1: matrix(p,'C1'),
}));
assert.equal(joints.length, 15, 'Actual R15 rig joints');
function solve(pose) {
  const bones = {R15Preview_RigRoot:I};
  for (const j of joints) {
    const transform = pose[j.name === 'Core' ? 'Root' : j.name] || I;
    assert(bones[j.parent], 'Topological rig order');
    bones[j.child] = mul(mul(mul(bones[j.parent],j.c0),transform),inv(j.c1));
  }
  return bones;
}
const clip = clips[sourceName];
assert(clip && clip.duration === .38);
const trail = source.match(/elapsed >= ([\d.]+) and elapsed <= ([\d.]+)/).slice(1).map(Number);
const keys = clip.keys.filter(k => k.time >= trail[0]/clip.duration && k.time <= trail[1]/clip.duration);
assert(keys.length > 20, 'Measure the whole sweep, not a single impact frame');
const motion = [];
for (const key of keys) {
  const rightPose = Object.fromEntries(Object.entries(key.values).map(([n,v]) => [n,cf(v.p,v.r)]));
  const leftPose = Object.fromEntries(Object.entries(rightPose).map(([n,v]) => [mirrorName(n),mirror(v)]));
  const r = solve(rightPose), l = solve(leftPose);
  const right = mul(r.R15Preview_RightHand,cf([0,-.25,0]));
  const left = mul(l.R15Preview_LeftHand,cf([0,-.25,0]));
  const reflected = mirror(right);
  assert(reflected.every((v,i) => Math.abs(v-left[i]) < 1e-6), 'The full hand trajectory reflects exactly');
  assert(Math.abs(right[8]) < Math.sin(2*Math.PI/180), 'Horizontal cutting direction');
  assert(Math.abs(right[6]) > .98, 'Blade thickness axis is vertical, so its cutting plane is horizontal');
  const rightX = mul(inv(r.R15Preview_UpperTorso),right)[0];
  const leftX = mul(inv(l.R15Preview_UpperTorso),left)[0];
  motion.push({u:key.time,rightX,leftX});
}
assert(motion[0].rightX > .2 && motion.at(-1).rightX < -.2, 'Right arm must cross RIGHT to LEFT');
assert(motion[0].leftX < -.2 && motion.at(-1).leftX > .2, 'Left arm must cross LEFT to RIGHT');
console.log('DUAL_INWARD_R15_FK_OK', JSON.stringify({sourceClip:sourceName,measuredFrames:keys.length,start:motion[0],end:motion.at(-1),studioRuntimeTest:false}));
