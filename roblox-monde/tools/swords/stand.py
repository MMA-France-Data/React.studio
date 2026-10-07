# Allege le stand des epees (Meshy) pour Roblox et rend une image de controle.
#   blender --background --python tools/swords/stand.py
# Ecrit assets/swords-roblox/A-IMPORTER/Stand_Epees.fbx (au plus 19 000 triangles, textures 1024 dans le FBX, pose
# sur le sol, HEIGHT studs de haut, debout) et assets/swords-roblox/apercu-stand.png. La source n est pas modifiee.
import bpy, glob, os
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC, OUT = os.path.join(ROOT, 'assets', 'stand-meshy'), os.path.join(ROOT, 'assets', 'swords-roblox')
TARGET, HEIGHT = 19000, 13.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=glob.glob(os.path.join(SRC, '*.fbx'))[0])
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if before > TARGET:
    mod = obj.modifiers.new('Decimate', 'DECIMATE')
    mod.ratio = TARGET / before
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
mesh = obj.data
pts = [v.co.copy() for v in mesh.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
scale = HEIGHT / (hi.z - lo.z)
for v in mesh.vertices:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * scale, (v.co.y - (lo.y + hi.y) / 2) * scale, (v.co.z - lo.z) * scale))
mesh.update()
size = (hi - lo) * scale
obj.name = mesh.name = 'Stand_Epees'
mat = bpy.data.materials.new('Stand_Epees'); mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes['Principled BSDF']
def find(suffix):
    files = [f for f in glob.glob(os.path.join(SRC, '*.png')) if (f.endswith(suffix + '.png') if suffix else not any(f.endswith(s + '.png') for s in ('_metallic', '_normal', '_roughness')))]
    return files[0] if files else None
def texture(suffix, name, colour):
    path = find(suffix)
    if not path:
        return None
    image = bpy.data.images.load(path); image.scale(1024, 1024)
    image.filepath_raw = os.path.join(OUT, 'stand-' + name + '.png'); image.file_format = 'PNG'; image.save()
    node = nodes.new('ShaderNodeTexImage'); node.image = image
    if not colour:
        image.colorspace_settings.name = 'Non-Color'
    return node
c = texture('', 'baseColor', True)
if c: links.new(c.outputs['Color'], bsdf.inputs['Base Color'])
m = texture('_metallic', 'metallic', False)
if m: links.new(m.outputs['Color'], bsdf.inputs['Metallic'])
r = texture('_roughness', 'roughness', False)
if r: links.new(r.outputs['Color'], bsdf.inputs['Roughness'])
n = texture('_normal', 'normal', False)
if n:
    bump = nodes.new('ShaderNodeNormalMap'); links.new(n.outputs['Color'], bump.inputs['Color']); links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
mesh.materials.clear(); mesh.materials.append(mat)
os.makedirs(os.path.join(OUT, 'A-IMPORTER'), exist_ok=True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, 'A-IMPORTER', 'Stand_Epees.fbx'), use_selection=True, axis_forward='-Z', axis_up='Y', apply_unit_scale=True, path_mode='COPY', embed_textures=True, bake_space_transform=True, mesh_smooth_type='FACE')
print('STAND triangles %d -> %d ; taille (x, y, hauteur) %.1f %.1f %.1f' % (before, sum(len(p.vertices) - 2 for p in mesh.polygons), size.x, size.y, size.z))
# L image de controle : de face et de trois quarts.
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(size.x, size.y, size.z) * 1.5
camera = bpy.data.objects.new('cam', cam); bpy.context.scene.collection.objects.link(camera)
camera.location = (14, -22, 14); 
bpy.context.scene.camera = camera
target = bpy.data.objects.new('t', None); target.location = (0, 0, HEIGHT / 2); bpy.context.scene.collection.objects.link(target)
track = camera.constraints.new('TRACK_TO'); track.target = target
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'; scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
scene.render.filepath = os.path.join(OUT, 'apercu-stand.png')
bpy.ops.render.render(write_still=True)
print('RENDU')
