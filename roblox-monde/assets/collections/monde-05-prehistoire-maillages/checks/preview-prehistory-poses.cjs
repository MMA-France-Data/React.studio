// Exact native transforms, with separate locomotion contracts for air and ground.
const fs=require('node:fs'),path=require('node:path'),m=require('./combat-math.cjs');
const out=path.resolve(process.argv[2]),spec=JSON.parse(fs.readFileSync(path.join(out,'native-rig-spec.json'))),author=JSON.parse(fs.readFileSync(path.join(out,'authoring-rig.json')));
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
function frames(pose){const result={RigRoot:m.I};for(const j of spec.joints)result[j.child]=m.mul(m.mul(m.mul(result[j.parent],j.c0),pose[j.name]||m.I),m.inv(j.c1));return result;}
function lowest(name,cf){return Math.min(...spec.parts.find(p=>p.name===name).vertices.map(v=>m.mul(cf,m.cf(v))[1]));}
const rest=frames({}),report={passed:false,id:spec.id,actualStudioTest:false,sampledWalkFrames:121,locomotion:author.locomotion};
if(author.locomotion==='flight'){
 let maxStroke=0,maxMismatch=0,minSpan=Infinity;
 for(let i=0;i<=120;i++){
  const u=i/120,clip=spec.animations.Walk,pose=m.sample(clip,u),world=frames(pose);
  const l=pose.WingL||m.I,r=pose.WingR||m.I;
  maxStroke=Math.max(maxStroke,Math.abs(Math.atan2(l[6],l[3])));
  maxMismatch=Math.max(maxMismatch,Math.abs(l[6]+r[6]));
  minSpan=Math.min(minSpan,Math.abs(world.WingTipR[0]-world.WingTipL[0]));
 }
 assert(maxStroke>.40,'Wing loop too rigid');assert(maxMismatch<.00001,'Wing strokes not mirrored');assert(minSpan>3.0,'Flying wings collapse');
 assert(author.supportLimbs.length===0&&author.forelimbs.join(',')==='WingL,WingR','Flight treated as quadruped');
 Object.assign(report,{forelimbs:author.forelimbs,supportLimbs:[],maxStrokeRadians:maxStroke,maxWingMismatch:maxMismatch,minimumWingTipSpan:minSpan,forelimbsWeightBearing:false});
}else{
 let maximumStanceError=0,maximumFootPitch=0,maximumSwingLift=0,minimumArmClearance=Infinity;
 const ground=Math.min(...author.legDefinitions.map(d=>lowest('Foot'+d.end,rest['Foot'+d.end])));
 for(let i=0;i<=120;i++){
  const u=i/120,world=frames(m.sample(spec.animations.Walk,u));
  for(const d of author.legDefinitions){
   const name='Foot'+d.end,foot=world[name],low=lowest(name,foot),cycle=u*Math.PI*2+d.phase;
   if(Math.cos(cycle)<-.05)maximumStanceError=Math.max(maximumStanceError,Math.abs(low-ground));
   maximumFootPitch=Math.max(maximumFootPitch,Math.abs(foot[8]));maximumSwingLift=Math.max(maximumSwingLift,low-ground);
  }
  for(const name of ['ForearmL','ForearmR'])if(world[name])minimumArmClearance=Math.min(minimumArmClearance,lowest(name,world[name])-ground);
 }
 assert(maximumStanceError<.012,'Stance not planted '+maximumStanceError);assert(maximumFootPitch<.001,'Feet not counter rotated');
 assert(Math.abs(maximumSwingLift-author.walkLift)<.025,'Wrong foot lift');
 if(author.locomotion==='biped')assert(minimumArmClearance>.65,'Arms supporting the body');
 Object.assign(report,{ground,supportLimbs:author.supportLimbs,forelimbs:author.forelimbs,forelimbsWeightBearing:false,maximumStanceError,maximumFootPitch,maximumSwingLift,minimumArmClearance:Number.isFinite(minimumArmClearance)?minimumArmClearance:null});
}
const sequences=[];
for(const [clipName,count]of [['Walk',14],['Attack',12],['Bite',10]])for(let i=0;i<count;i++){
 const clip=spec.animations[clipName],u=i/(clipName==='Walk'?count:count-1),world=frames(m.sample(clip,u));
 sequences.push({clip:clipName,index:i,time:u,seconds:clip.duration*u,duration:clip.duration/count,delta:Object.fromEntries(spec.parts.map(p=>[p.name,m.mul(world[p.name],m.inv(p.cf))]))});
}
report.passed=true;fs.writeFileSync(path.join(out,'preview-poses.json'),JSON.stringify({sequences})+'\n');fs.writeFileSync(path.join(out,'LOCOMOTION-VALIDATION.json'),JSON.stringify(report,null,2)+'\n');console.log('LOCOMOTION_VERIFIED',JSON.stringify(report));
