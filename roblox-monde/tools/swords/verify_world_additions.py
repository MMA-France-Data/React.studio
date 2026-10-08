"""Reimport the four actual exported weapons; never assert a Studio test."""
import argparse, hashlib, json, os, sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

parser=argparse.ArgumentParser()
parser.add_argument('--assets', required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=os.path.abspath(args.assets)
reports=[]
for identity in ['TigerClaw','HyenaFang','TrexJaw','Meteorite']:
    directory=os.path.join(root,identity)
    with open(os.path.join(directory,'info.json'),encoding='utf-8') as handle:
        info=json.load(handle)
    model=os.path.join(directory,'Sword_'+identity+'.fbx')
    copy=os.path.join(root,'A-IMPORTER','Sword_'+identity+'.fbx')
    assert hashlib.sha256(open(model,'rb').read()).digest()==hashlib.sha256(open(copy,'rb').read()).digest(), 'Import copy changed'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=model)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1, 'One visible mesh required'
    obj=meshes[0]
    assert obj.name=='Sword_'+identity, 'Importer name changed'
    triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
    assert triangles==info['triangles'] and 0<triangles<=19000, 'Triangle budget failed'
    assert obj.data.uv_layers.active, 'UVs missing'
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    span=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
    assert abs(span[1]-5.2)<.015 and span[1]>span[0] and span[1]>span[2], 'Blade axis/length incorrect'
    grip=[p for p in points if abs(p.y)<.09]
    assert grip, 'Grip section empty'
    grip_error=max(abs((min(p[i] for p in grip)+max(p[i] for p in grip))*.5) for i in [0,2])
    assert grip_error<.04, 'Grip is not centered on the shaft'
    assert info['gripAt']==[0,0,0] and info['trailTip'][2]<info['trailBase'][2]<0, 'Invalid canonical attachments'
    tree=BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
    distances={}
    for key in ['trailBase','trailTip']:
        value=info[key]
        target=Vector((value[0],-value[2],value[1]))
        local=obj.matrix_world.inverted()@target
        nearest=tree.find_nearest(local)
        assert nearest and nearest[0] is not None, 'Empty blade surface'
        distance=(obj.matrix_world@nearest[0]-target).length
        # Base is inside the real blade cross-section, not necessarily on its skin.
        limit=max(.20,.25*span[0]) if key=='trailBase' else .20
        assert distance<limit, 'Detached trail attachment: '+key
        distances[key]=round(distance,6)
    mats=[m for m in obj.data.materials if m and m.use_nodes]
    textures=[n.image for m in mats for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert len(textures)>=4 and all(0<max(i.size)<=1024 for i in textures), 'PBR maps incomplete/oversized'
    for kind in ['baseColor','normal','metallic','roughness']:
        original=os.path.join(directory,kind+'.png')
        bundled=os.path.join(root,'A-IMPORTER','Sword_'+identity+'.fbm',kind+'.png')
        assert hashlib.sha256(open(original,'rb').read()).digest()==hashlib.sha256(open(bundled,'rb').read()).digest(), 'External texture copy differs'
    report={'id':identity,'passed':True,'actualStudioTest':False,'triangles':triangles,'visibleMeshes':1,
            'length':round(span[1],6),'maxGripCenterError':round(grip_error,6),
            'trailSurfaceDistances':distances,'UVs':True,'PBRMaps':len(textures),'maxTextureSize':1024}
    reports.append(report)
    print('WORLD_SWORD_FBX_OK',json.dumps(report))
with open(os.path.join(root,'IMPORT-VALIDATION.json'),'w',encoding='utf-8') as handle:
    json.dump({'passed':True,'actualStudioTest':False,'swords':reports},handle,indent=2)
