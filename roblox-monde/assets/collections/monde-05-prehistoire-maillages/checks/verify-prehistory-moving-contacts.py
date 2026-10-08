"""All parent joints under exact animation deltas on actual reimported geometry."""
import bpy,json,sys,numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
out=Path(next(a.split('=',1)[1] for a in sys.argv if a.startswith('--directory='))).resolve()
spec=json.loads((out/'native-rig-spec.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/(spec['id']+'-Import3D-Motor6D.fbx')))
members={}
for p in spec['parts']:
 obj=bpy.data.objects[p['fbxName']];v=np.array([tuple(obj.matrix_world@v.co) for v in obj.data.vertices])
 members[p['name']]=(np.column_stack((v[:,0],v[:,2],-v[:,1])),[tuple(f.vertices) for f in obj.data.polygons])
poses=json.loads((out/'preview-poses.json').read_text(encoding='utf-8'))['sequences']
contacts=[];failures=[]
for frame in poses:
 world={};trees={}
 for name,(v,faces) in members.items():
  cf=frame['delta'][name];world[name]=v@np.array(cf[3:]).reshape(3,3).T+np.array(cf[:3])
  trees[name]=BVHTree.FromPolygons([Vector(p) for p in world[name]],faces,all_triangles=True)
 for joint in spec['joints']:
  child,parent=joint['child'],joint['parent']
  if parent=='RigRoot':continue
  tree=trees[parent];cv=world[child];pv=world[parent];intersect=bool(tree.overlap(trees[child]));minimum=float('inf');inside=False
  for p in cv:
   hit,normal,_,d=tree.find_nearest(Vector(p));minimum=min(minimum,d)
   if np.all(p>=pv.min(axis=0)-.001) and np.all(p<=pv.max(axis=0)+.001) and np.dot(p-np.array(hit),np.array(normal))<-.00005:inside=True
  connected=intersect or inside or minimum<.008
  row={'clip':frame['clip'],'sample':frame['index'],'member':child,'parent':parent,'connected':connected,'minimumGap':minimum}
  contacts.append(row)
  if not connected:failures.append(row)
report={'passed':not failures,'id':spec['id'],'actualStudioTest':False,'testedFrames':len(poses),'memberContactCases':len(contacts),'detached':failures,'contacts':contacts}
(out/'MOVING-CONTACT-VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('MOVING_CONTACTS_CHECK',spec['id'],'cases',len(contacts),'detached',failures,flush=True)
assert not failures,'Moving joints detached'
