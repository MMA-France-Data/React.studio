"""Contacts of the moving frill and jaw, evaluated on actual reimported FBX meshes."""
import bpy,json,sys
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
selected=[a.split('=',1)[1] for a in sys.argv if a.startswith('--directory=')]
assert selected,'Pass --directory=asset-folder'
out=Path(selected[0]).resolve();spec=json.loads((out/'native-rig-spec.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(out/(spec['id']+'-Import3D-Motor6D.fbx')))
members={}
for p in spec['parts']:
 obj=bpy.data.objects[p['fbxName']];verts=np.array([tuple(obj.matrix_world@v.co) for v in obj.data.vertices])
 verts=np.column_stack((verts[:,0],verts[:,2],-verts[:,1]))
 members[p['name']]=(verts,[tuple(f.vertices) for f in obj.data.polygons])
def transformed(v,c):return v@np.array(c[3:]).reshape(3,3).T+np.array(c[:3])
poses=json.loads((out/'preview-poses.json').read_text(encoding='utf-8'))['sequences']
contacts=[];failures=[]
for frame in poses:
 for child,parent in [('FrillL','Head'),('FrillR','Head'),('Jaw','Head')]:
  cv,cf=members[child];pv,pf=members[parent]
  cv=transformed(cv,frame['delta'][child]);pv=transformed(pv,frame['delta'][parent])
  ct=BVHTree.FromPolygons([Vector(v) for v in cv],cf,all_triangles=True)
  pt=BVHTree.FromPolygons([Vector(v) for v in pv],pf,all_triangles=True)
  intersect=bool(pt.overlap(ct));minimum=min(pt.find_nearest(Vector(v))[3] for v in cv)
  connected=intersect or minimum<.008
  row={'clip':frame['clip'],'sample':frame['index'],'member':child,'parent':parent,'intersectingSurfaces':intersect,'minimumGap':minimum,'connected':connected}
  contacts.append(row)
  if not connected:failures.append(row)
report={'passed':not failures,'actualStudioTest':False,'id':spec['id'],'testedFrames':len(poses),'memberContactCases':len(contacts),'detached':failures,'contacts':contacts}
(out/'MOVING-FRILL-VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('MOVING_FRILL_CHECK',spec['id'],'cases',len(contacts),'detached',failures,flush=True)
assert not failures,'Moving frill or jaw detached'
