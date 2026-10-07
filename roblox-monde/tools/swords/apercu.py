# Rend une image de controle des sept epees allegees (assets/swords-roblox/apercu.png), avec leur texture de couleur.
# Les epees sont cote a cote, pointe en bas ; le point rouge (la prise) doit etre au milieu de la poignee.
#   blender --background --python tools/swords/apercu.py
import bpy, json, os, glob
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC, OUT = os.path.join(ROOT, 'assets', 'swords-meshy'), os.path.join(ROOT, 'assets', 'swords-roblox')
NAMES = ['Iron', 'Steel', 'Gold', 'Frost', 'Flame', 'Storm', 'Prismatic']
manifest = json.load(open(os.path.join(SRC, 'IMPORT_QA.json'), encoding='utf-8'))
colors = {m['id']: m['textures']['baseColor']['file'] for m in manifest['models']}
bpy.ops.wm.read_factory_settings(use_empty=True)
for row, name in enumerate(NAMES):
    bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, name, 'Sword_%s.fbx' % name))
    obj = bpy.context.selected_objects[0]
    obj.location = Vector((0, row * 2.0, 0))   # (apres import, la lame est verticale : les epees sont cote a cote)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(SRC, colors[name]))
    bsdf = mat.node_tree.nodes['Principled BSDF']
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    # La croix rouge a l origine du modele (la prise).
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=obj.location)
    dot = bpy.context.active_object
    red = bpy.data.materials.new('red'); red.diffuse_color = (1, 0, 0, 1)
    dot.data.materials.append(red)
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = 15
camera = bpy.data.objects.new('cam', cam); bpy.context.scene.collection.objects.link(camera)
# Vue de face : on regarde le long de l epaisseur. Apres import (-Z avant, Y haut), la lame (Roblox -Z) est sur +Y Blender.
camera.location = (20, 6, -1.6); camera.rotation_euler = (1.5708, 0, 1.5708)
bpy.context.scene.camera = camera
light = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); light.rotation_euler = (1.2, 0, 1.2); light.data.energy = 4
bpy.context.scene.collection.objects.link(light)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'; scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 1500, 900
scene.render.filepath = os.path.join(OUT, 'apercu.png')
bpy.ops.render.render(write_still=True)
print('RENDU')
