const fs=require('node:fs'),path=require('node:path');
const out=process.argv[2]?path.resolve(process.argv[2]):path.resolve(__dirname,'../../outputs/monde-05-prehistoire-maillages/Velociraptor');
const egg=JSON.parse(fs.readFileSync(path.join(out,fs.existsSync(path.join(out,'egg-data.json'))?'egg-data.json':'raptor-egg-data.json'),'utf8'));
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0),sub=(a,b)=>a.map((v,i)=>v-b[i]);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const axes=p=>[0,1,2].map(i=>[p.cf[3+i],p.cf[6+i],p.cf[9+i]]);
function touches(a,b){
 const aa=axes(a),bb=axes(b),delta=sub(b.cf.slice(0,3),a.cf.slice(0,3));
 for(const ax of [...aa,...bb,...aa.flatMap(x=>bb.map(y=>cross(x,y)))]){
  const length=Math.hypot(...ax);if(length<1e-7)continue;
  const radius=(p,base)=>base.reduce((s,v,i)=>s+Math.abs(dot(ax,v))*p.size[i]/2,0);
  if(Math.abs(dot(delta,ax))>radius(a,aa)+radius(b,bb)+.0005*length)return false;
 }
 return true;
}
const reached=new Set([0]);let progress=true;
while(progress){progress=false;for(let i=0;i<egg.parts.length;i++)if(!reached.has(i)&&[...reached].some(j=>touches(egg.parts[i],egg.parts[j]))){reached.add(i);progress=true;}}
const detached=egg.parts.filter((p,i)=>!reached.has(i)).map(p=>p.name);
if(detached.length)throw Error('Detached egg pieces: '+detached.join(', '));
if(egg.nests!==false||egg.parts.some(p=>p.size.some(v=>v<=0||!Number.isFinite(v))))throw Error('Egg shape invalid');
const report={passed:true,actualStudioTest:false,id:egg.id,baseParts:egg.parts.length+1,noNest:true,
 connectedGeometryPieces:reached.size,detachedGeometryPieces:detached,method:'15-axis oriented-box contact, connected component'};
fs.writeFileSync(path.join(out,'EGG-VALIDATION.json'),JSON.stringify(report,null,2)+'\n');
console.log('RAPTOR_EGG_CHECKED',JSON.stringify(report));
