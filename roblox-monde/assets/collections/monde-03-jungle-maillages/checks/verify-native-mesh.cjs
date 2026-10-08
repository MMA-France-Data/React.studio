const fs=require('node:fs'),path=require('node:path'),m=require('./combat-math.cjs');
const dir=path.resolve(process.argv[2]);
const spec=JSON.parse(fs.readFileSync(path.join(dir,'native-rig-spec.json'),'utf8'));
const source=JSON.parse(fs.readFileSync(path.join(dir,'source-rig-and-clips.json'),'utf8'));
function assert(value,message){if(!value)throw Error(message);}
assert(spec.root==='RigRoot'&&spec.parts.length+1<20,'Root / part budget');
assert(JSON.stringify(spec.joints.map(j=>[j.name,j.parent,j.child]))===JSON.stringify(source.joints.map(j=>[j.name,j.parent,j.child])),'Original joint graph changed');
assert(JSON.stringify(spec.animations)===JSON.stringify(source.animations),'Original animation data changed');
assert(spec.parts.every(p=>(p.group||p.name)===spec.joints.find(j=>j.child===(p.group||p.name))?.name),'Animation member names changed');
let cases=0,maxError=0;const clips={};
const transforms=(joints,poses)=>{
 const frames={RigRoot:m.I};for(const j of joints)frames[j.child]=m.mul(m.mul(m.mul(frames[j.parent],j.c0),poses[j.name]||m.I),m.inv(j.c1));return frames;
};
const sourceFrames=source.partFrames||transforms(source.joints,{});
const rest=transforms(spec.joints,{});
function withDecorations(frames){
 for(const p of spec.parts)if(p.group&&p.group!==p.name)frames[p.name]=m.mul(m.mul(frames[p.group],m.inv(rest[p.group])),p.cf);
 return frames;
}
for(const p of spec.parts){
 if(!p.group||p.group===p.name)assert(Math.max(...rest[p.name].map((v,i)=>Math.abs(v-p.cf[i])))<.00001,'Bad rest '+p.name);
 assert(p.size.every(x=>Number.isFinite(x)&&x>0),'Bad size');
}
for(const [name,clip] of Object.entries(spec.animations)){
 const duration=clip.duration;let low=Infinity,high=-Infinity;
 for(let i=0;i<=80;i++){
  const pose=m.sample(clip,i/80),actual=withDecorations(transforms(spec.joints,pose)),previous=transforms(source.joints,pose);
  for(const p of spec.parts){
   const parent=p.group||p.name;const expected=m.mul(m.mul(previous[parent],m.inv(sourceFrames[parent])),p.cf);
   const error=Math.max(...actual[p.name].map((v,k)=>Math.abs(v-expected[k])));maxError=Math.max(maxError,error);
   assert(error<.00002,'Retarget changed pose '+name+'/'+p.name);
   for(const vertex of p.vertices){
    const v=m.mul(actual[p.name],m.cf(vertex)).slice(0,3);assert(v.every(Number.isFinite),'Bad deformation');low=Math.min(low,v[1]);high=Math.max(high,v[1]);
   }
   cases++;
  }
 }
 if(name==='Attack'||name==='Bite')assert(clip.loop===false&&clip.frames.filter(f=>f.event==='Impact').length===1,'Missing non-loop Impact');
 else assert(clip.loop!==false,'Lost looping clip');
 clips[name]={duration,loop:clip.loop!==false,minHeight:low,maxHeight:high};
}
const report={passed:true,actualStudioTest:false,id:spec.id,basePartsAfterAssembly:spec.parts.length+1,motor6D:spec.joints.length,
 rigidWelds:spec.parts.filter(p=>p.group&&p.group!==p.name).length,
 originalJointNames:true,originalClipsUnchanged:true,vertexPoseCases:cases,maxRetargetMatrixError:maxError,clips};
fs.writeFileSync(path.join(dir,'NATIVE-VALIDATION.json'),JSON.stringify(report,null,2)+'\n');
console.log('NATIVE_MESH_VERIFIED',JSON.stringify(report));
