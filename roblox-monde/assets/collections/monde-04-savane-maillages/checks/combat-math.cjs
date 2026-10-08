// Roblox row-major CFrames, including the quaternion interpolation used by Lerp.
const I=[0,0,0,1,0,0,0,1,0,0,0,1];
function mul(a,b){const c=I.slice();for(let i=0;i<3;i++){c[i]=a[i]+[0,1,2].reduce((s,k)=>s+a[3+i*3+k]*b[k],0);for(let j=0;j<3;j++)c[3+i*3+j]=[0,1,2].reduce((s,k)=>s+a[3+i*3+k]*b[3+k*3+j],0);}return c;}
function inv(a){const c=I.slice();for(let i=0;i<3;i++)for(let j=0;j<3;j++)c[3+i*3+j]=a[3+j*3+i];for(let i=0;i<3;i++)c[i]=-[0,1,2].reduce((s,k)=>s+c[3+i*3+k]*a[k],0);return c;}
function cf(p=[0,0,0],r=[0,0,0]){
 const [x,y,z]=r,cx=Math.cos(x),sx=Math.sin(x),cy=Math.cos(y),sy=Math.sin(y),cz=Math.cos(z),sz=Math.sin(z);
 return [...p,cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy];
}
function quaternion(c){
 const m=c.slice(3),tr=m[0]+m[4]+m[8];let q;
 if(tr>0){const s=Math.sqrt(tr+1)*2;q=[(m[7]-m[5])/s,(m[2]-m[6])/s,(m[3]-m[1])/s,s/4];}
 else if(m[0]>m[4]&&m[0]>m[8]){const s=Math.sqrt(1+m[0]-m[4]-m[8])*2;q=[s/4,(m[1]+m[3])/s,(m[2]+m[6])/s,(m[7]-m[5])/s];}
 else if(m[4]>m[8]){const s=Math.sqrt(1+m[4]-m[0]-m[8])*2;q=[(m[1]+m[3])/s,s/4,(m[5]+m[7])/s,(m[2]-m[6])/s];}
 else{const s=Math.sqrt(1+m[8]-m[0]-m[4])*2;q=[(m[2]+m[6])/s,(m[5]+m[7])/s,s/4,(m[3]-m[1])/s];}
 const len=Math.hypot(...q);return q.map(v=>v/len);
}
function lerp(a,b,t){
 let qa=quaternion(a),qb=quaternion(b),dot=qa.reduce((s,v,i)=>s+v*qb[i],0);if(dot<0){qb=qb.map(v=>-v);dot=-dot;}
 let q;
 if(dot>.9995){q=qa.map((v,i)=>v+(qb[i]-v)*t);const len=Math.hypot(...q);q=q.map(v=>v/len);}
 else{const theta=Math.acos(Math.min(1,dot)),sin=Math.sin(theta);q=qa.map((v,i)=>(v*Math.sin((1-t)*theta)+qb[i]*Math.sin(t*theta))/sin);}
 const [x,y,z,w]=q,p=a.slice(0,3).map((v,i)=>v+(b[i]-v)*t);
 return [...p,1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)];
}
function sample(clip,u){
 const frames=clip.frames;if(u<=0)return Object.fromEntries(Object.entries(frames[0].pose).map(([name,v])=>[name,cf(v.p,v.r)]));
 let index=frames.findIndex(f=>f.time>=u);if(index<0)index=frames.length-1;if(index===0)index=1;
 const a=frames[index-1],b=frames[index],t=Math.max(0,Math.min(1,(u-a.time)/(b.time-a.time)));
 return Object.fromEntries(Object.keys(a.pose).map(name=>[name,lerp(cf(a.pose[name].p,a.pose[name].r),cf(b.pose[name].p,b.pose[name].r),t)]));
}
function partsAt(pet,transforms){
 const byName=new Map(pet.parts.map(p=>[p.name,p])),bones={RigRoot:I};
 for(const j of pet.joints)bones[j.child]=mul(mul(mul(bones[j.parent],j.c0),transforms[j.name]||I),inv(j.c1));
 return pet.parts.map(p=>({part:p,cf:mul(bones[p.group],mul(inv(byName.get(p.group).cf),p.cf))}));
}
function bounds(pet,transforms){
 const low=[Infinity,Infinity,Infinity],high=[-Infinity,-Infinity,-Infinity];
 for(const {part:p,cf:c}of partsAt(pet,transforms))for(const x of [-.5,.5])for(const y of [-.5,.5])for(const z of [-.5,.5]){
  const v=mul(c,cf([x*p.size[0],y*p.size[1],z*p.size[2]])).slice(0,3);
  for(let i=0;i<3;i++){low[i]=Math.min(low[i],v[i]);high[i]=Math.max(high[i],v[i]);}
 }return {low,high};
}
function grounded(pet,transforms){
 const result=Object.fromEntries(Object.entries(transforms).map(([name,c])=>[name,c.slice()]));
 // Match the helper's binding-relative ground correction. Core is rooted directly.
 const lift=Math.max(0,-pet.size[1]/2-bounds(pet,result).low[1]);
 result.Core[1]+=lift;return result;
}
module.exports={I,mul,inv,cf,lerp,sample,partsAt,bounds,grounded};
