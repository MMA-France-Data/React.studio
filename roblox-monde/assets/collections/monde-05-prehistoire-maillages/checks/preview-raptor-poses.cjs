// Preview uses the exact native Motor6D transforms, not a substitute animation.
const fs=require('node:fs'),path=require('node:path'),m=require('./combat-math.cjs');
const out=process.argv[2]?path.resolve(process.argv[2]):path.resolve(__dirname,'../../outputs/monde-05-prehistoire-maillages/Velociraptor');
const spec=JSON.parse(fs.readFileSync(path.join(out,'native-rig-spec.json'),'utf8'));
const authoring=JSON.parse(fs.readFileSync(path.join(out,'authoring-rig.json'),'utf8'));
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
function frames(pose){
 const result={RigRoot:m.I};
 for(const j of spec.joints)result[j.child]=m.mul(m.mul(m.mul(result[j.parent],j.c0),pose[j.name]||m.I),m.inv(j.c1));
 return result;
}
function lowest(name,cf){return Math.min(...spec.parts.find(p=>p.name===name).vertices.map(v=>m.mul(cf,m.cf(v))[1]));}
const rest=frames({}),ground=Math.min(lowest('FootBL',rest.FootBL),lowest('FootBR',rest.FootBR));
let minimumArmClearance=Infinity,maximumStanceError=0,maximumFootPitch=0,maximumSwingLift=0;
for(let i=0;i<=120;i++){
 const u=i/120,pose=m.sample(spec.animations.Walk,u),world=frames(pose);
 for(const side of ['L','R']){
  const cycle=u*Math.PI*2+(side==='L'?0:Math.PI),foot=world['FootB'+side];
  const low=lowest('FootB'+side,foot);
  if(Math.cos(cycle)<-.05)maximumStanceError=Math.max(maximumStanceError,Math.abs(low-ground));
  maximumSwingLift=Math.max(maximumSwingLift,low-ground);
  maximumFootPitch=Math.max(maximumFootPitch,Math.abs(foot[8]));
  minimumArmClearance=Math.min(minimumArmClearance,lowest('Forearm'+side,world['Forearm'+side])-ground);
 }
}
assert(maximumStanceError<.012,'Walking stance foot not planted: '+maximumStanceError);
assert(maximumFootPitch<.001,'Foot fails to counter-rotate');
assert(minimumArmClearance>.65,'Forearm too close to floor');
const intendedLift=authoring.walkLift||.16;
assert(Math.abs(maximumSwingLift-intendedLift)<.025,'Walking hind-foot lift is wrong');
if(authoring.frillMembers){
 const clip=spec.animations.Attack;
 assert(clip.frames.some(f=>f.pose.FrillL.r[1]<-1.15&&f.pose.FrillR.r[1]>1.15),'Frill never opens');
 for(const f of clip.frames)assert(Math.abs(f.pose.FrillL.r[1]+f.pose.FrillR.r[1])<.00001,'Frill opening is asymmetric');
}
const sequences=[];
for(const [clipName,count]of [['Walk',14],['Attack',12],['Bite',10]]){
 const clip=spec.animations[clipName];
 for(let i=0;i<count;i++){
  const u=i/(clipName==='Walk'?count:count-1),world=frames(m.sample(clip,u));
  const delta=Object.fromEntries(spec.parts.map(p=>[p.name,m.mul(world[p.name],m.inv(p.cf))]));
  sequences.push({clip:clipName,index:i,time:u,seconds:clip.duration*u,duration:clip.duration/count,delta});
 }
}
fs.writeFileSync(path.join(out,'preview-poses.json'),JSON.stringify({sequences})+'\n');
const report={passed:true,actualStudioTest:false,sampledWalkFrames:121,supportLimbs:['LegBL','LegBR'],
 forelimbs:['ArmL','ArmR'],forelimbsWeightBearing:false,ground,minimumArmClearance,maximumStanceError,maximumFootPitch,maximumSwingLift};
fs.writeFileSync(path.join(out,'BIPED-VALIDATION.json'),JSON.stringify(report,null,2)+'\n');
console.log('BIPED_WALK_VERIFIED',JSON.stringify(report));
