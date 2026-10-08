import bpy,sys,json
from pathlib import Path
from mathutils import Matrix
import numpy as np
BASE=Path(__file__).resolve().parent.parent.parent
directories=[BASE/'outputs/monde-tigre-facettes-v2'] if '--tiger' in sys.argv else [BASE/'outputs/monde-jungle-maillages/Gorilla'] if '--gorilla' in sys.argv else [BASE/'outputs/monde-01-ferme-maillages'/n for n in ['Duck','Horse','Rooster','Pig','Sheep','Goat']]
selected=[a.split('=',1)[1] for a in sys.argv if a.startswith('--directory=')]
if selected:directories=[Path(p).resolve() for p in selected]
for out in directories:
    spec=json.loads((out/'native-rig-spec.json').read_text(encoding='utf-8'));identifier=spec['id']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    fbx=out/(identifier+'-Import3D-Motor6D.fbx')
    if not fbx.exists():fbx=out/(identifier+'.fbx')
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==len(spec['parts'])
    assert not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
    maximum_error=0;triangles=0
    for p in spec['parts']:
        obj=next(o for o in objects if o.name==p['fbxName'])
        coords=np.array([tuple(obj.matrix_world@v.co) for v in obj.data.vertices])
        # Back from Blender X/-Z/Y coordinates to Roblox X/Y/Z.
        coords=np.column_stack((coords[:,0],coords[:,2],-coords[:,1]))
        low=coords.min(axis=0);high=coords.max(axis=0)
        actual_center=(low+high)*.5;actual_size=high-low
        error=max(np.max(np.abs(actual_center-np.array(p['cf'][:3]))),np.max(np.abs(actual_size-np.array(p['size']))));maximum_error=max(maximum_error,float(error))
        assert error<.00001,(identifier,p['name'],error)
        assert obj.data.uv_layers.active and obj.data.materials
        assert np.isfinite(coords).all()
        triangles+=sum(len(poly.vertices)-2 for poly in obj.data.polygons)
    assert 4000<=triangles<=6000 and len(objects)+1<20
    report={'passed':True,'actualStudioTest':False,'id':identifier,'rigidMeshes':len(objects),'bones':0,'triangles':triangles,
        'maxRoundTripBoundsError':maximum_error,'texturesAndUV':True}
    (out/'FBX-VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('RIGID_FBX_VERIFIED',json.dumps(report),flush=True)
