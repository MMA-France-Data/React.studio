"""Rest-pose member contact and left/right geometry symmetry, on the actual FBX."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np
BASE=Path(__file__).resolve().parent.parent.parent
directories=[BASE/'outputs/monde-01-ferme-maillages'/n for n in ['Duck','Horse','Rooster','Pig','Sheep','Goat']]
directories += [BASE/'outputs/monde-tigre-facettes-v2',BASE/'outputs/monde-jungle-maillages/Gorilla']
selected=[a.split('=',1)[1] for a in sys.argv if a.startswith('--directory=')]
if selected:directories=[Path(p).resolve() for p in selected]
for out in directories:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spec=json.loads((out/'native-rig-spec.json').read_text(encoding='utf-8'))
    fbx=out/(spec['id']+'-Import3D-Motor6D.fbx')
    if not fbx.exists():fbx=out/(spec['id']+'.fbx')
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    members={};trees={}
    for p in spec['parts']:
        obj=next(o for o in bpy.context.scene.objects if o.name==p['fbxName'])
        v=np.array([tuple(obj.matrix_world@x.co) for x in obj.data.vertices]);v=np.column_stack((v[:,0],v[:,2],-v[:,1]))
        polygons=[tuple(f.vertices) for f in obj.data.polygons]
        members[p['name']]=(v,polygons);trees[p['name']]=BVHTree.FromPolygons([Vector(x) for x in v],polygons,all_triangles=True)
    contacts=[];failed=[]
    parents={j['child']:j['parent'] for j in spec['joints']}
    parents.update({p['name']:p['group'] for p in spec['parts'] if p.get('group',p['name'])!=p['name']})
    for name,parent in parents.items():
        if parent=='RigRoot':continue
        # Decorative weld pieces of a member form one physical anatomy region.
        related=[parent]+[p['name'] for p in spec['parts'] if p.get('group')==parent and p['name'] not in (name,parent)]
        pv=[];pf=[]
        for region in related:
            verts,faces=members[region];first=len(pv);pv.extend(verts);pf.extend([tuple(first+k for k in f) for f in faces])
        pv=np.array(pv);tree=BVHTree.FromPolygons([Vector(v) for v in pv],pf,all_triangles=True)
        vertices,_=members[name]
        overlap=bool(tree.overlap(trees[name]));inside=False;distance=float('inf')
        for point in vertices:
            hit,normal,_,d=tree.find_nearest(Vector(point));distance=min(distance,d)
            if np.all(point>=pv.min(axis=0)-.001) and np.all(point<=pv.max(axis=0)+.001) and np.dot(point-np.array(hit),np.array(normal))<-.00005:inside=True
        connected=overlap or inside or distance<.008
        contacts.append({'member':name,'parent':parent,'intersectingSurfaces':overlap,'embeddedVertex':inside,'minimumGap':distance,'connected':connected})
        if not connected:failed.append(name)
    symmetry=[]
    for left in members:
        right=left[:-1]+'R' if left.endswith('L') else None
        if right not in members:continue
        lv=members[left][0].copy();lv[:,0]=2*spec.get('symmetryAxis',0)-lv[:,0];rv=members[right][0]
        # Compare unordered coordinate sets, including relief studs.
        ordered=lambda a:np.array(sorted(map(tuple,np.round(a,5))))
        error=float(np.max(np.abs(ordered(lv)-ordered(rv)))) if len(lv)==len(rv) else None
        symmetry.append({'left':left,'right':right,'sameVertexCount':len(lv)==len(rv),'maximumMirrorError':error})
    symmetry_ok=all(s['maximumMirrorError'] is not None and s['maximumMirrorError']<.00003 for s in symmetry)
    report={'id':spec['id'],'restPoseOnly':True,'actualStudioTest':False,'passed':not failed and symmetry_ok,'detachedMembers':failed,'contacts':contacts,'symmetry':symmetry}
    (out/'CONTACT-VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('MESH_CONTACTS',spec['id'],'DETACHED',failed,'SYMMETRY',symmetry,flush=True)
