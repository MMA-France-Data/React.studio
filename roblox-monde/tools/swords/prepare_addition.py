"""Prepare ONLY a newly downloaded sword, locally and without Meshy API calls.

blender --background --python tools/swords/prepare_addition.py -- \
  --id Fusion --source /path/to/extracted --output /path/to/assets/swords-roblox

The source is read-only; existing swords and SwordMeshes.rbxm are never changed.
Grip intervals were checked against these two models, not guessed from the bbox.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

parser = argparse.ArgumentParser()
parser.add_argument('--id', choices=['Fusion', 'Void'], required=True)
parser.add_argument('--source', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source, output = os.path.abspath(args.source), os.path.abspath(args.output)
dest = os.path.join(output, args.id)
os.makedirs(dest, exist_ok=True)
paths = [os.path.join(source, p) for p in os.listdir(source) if p.lower().endswith('.fbx')]
assert len(paths) == 1, 'Exactly one source FBX required'
src = paths[0]
name = 'Sword_' + args.id
LENGTH, TARGET = 5.2, 19000
settings = {
    'Fusion': {'handle': (.125, .225), 'bladeStart': .365},
    'Void': {'handle': (.12, .195), 'bladeStart': .365},
}[args.id]
grip_from_pommel = sum(settings['handle']) * .5 * LENGTH

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes, 'No mesh in source'
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
original = obj.copy()
original.data = obj.data.copy()
bpy.context.scene.collection.objects.link(original)
original.hide_render = True
before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
points = [v.co.copy() for v in obj.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
span, center = hi - lo, (lo + hi) * .5
thick, wide, long = sorted(range(3), key=lambda i: span[i])
# Both inspected downloads: handle at low Z, point at high Z.
assert long == 2, 'Unrecognized orientation: inspect rather than guess'
scale = LENGTH / span[long]
for mesh in [obj.data, original.data]:
    for v in mesh.vertices:
        p = v.co.copy()
        v.co = Vector(((p[thick] - center[thick]) * scale,
                       (p[long] - lo[long]) * scale - grip_from_pommel,
                       (p[wide] - center[wide]) * scale))
    mesh.update()
# A curved sword's full bounding-box center is NOT the handle center. Align
# the actual grip cross-section, including its small sideways displacement.
handle_points = [v.co.copy() for v in original.data.vertices
                 if abs(v.co.y) < .09]
assert handle_points, 'Actual handle section not found'
handle_x = (min(p.x for p in handle_points) + max(p.x for p in handle_points)) * .5
handle_z = (min(p.z for p in handle_points) + max(p.z for p in handle_points)) * .5
for data in [obj.data, original.data]:
    for v in data.vertices:
        v.co.x -= handle_x
        v.co.z -= handle_z
    data.update()
if before > TARGET:
    mod = obj.modifiers.new('MobileTriangleBudget', 'DECIMATE')
    mod.ratio = (TARGET - 50) / before
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
mesh = obj.data
after = sum(len(p.vertices) - 2 for p in mesh.polygons)
assert after <= TARGET and mesh.uv_layers.active, 'Triangle / UV check failed'
obj.name = mesh.name = name

# Preserve the original UVs and the four PBR maps, reduced for mobile.
stem = os.path.splitext(os.path.basename(src))[0]
files = {'baseColor': stem + '.png', 'normal': stem + '_normal.png',
         'metallic': stem + '_metallic.png', 'roughness': stem + '_roughness.png'}
mat = bpy.data.materials.new(name)
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes['Principled BSDF']
images = {}
for kind, filename in files.items():
    path = os.path.join(source, filename)
    assert os.path.isfile(path), 'Missing ' + filename
    image = bpy.data.images.load(path, check_existing=False)
    if max(image.size) > 1024:
        image.scale(1024, 1024)
    image.filepath_raw = os.path.join(dest, kind + '.png')
    image.file_format = 'PNG'
    image.save()
    if kind != 'baseColor':
        image.colorspace_settings.name = 'Non-Color'
    images[kind] = image
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = image
    if kind == 'normal':
        normal = nodes.new('ShaderNodeNormalMap')
        links.new(tex.outputs['Color'], normal.inputs['Color'])
        links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
    else:
        links.new(tex.outputs['Color'], bsdf.inputs[{'baseColor': 'Base Color', 'metallic': 'Metallic', 'roughness': 'Roughness'}[kind]])
for data in [mesh, original.data]:
    data.materials.clear()
    data.materials.append(mat)
    for poly in data.polygons:
        poly.material_index = 0

# Hot / cold wisp sources are sampled from ACTUAL texture-colored surface
# vertices, alternating the two blade faces. No big tube or guessed cone.
width, height = images['baseColor'].size
pixels = np.empty(width * height * 4, dtype=np.float32)
images['baseColor'].pixels.foreach_get(pixels)
pixels = pixels.reshape(height, width, 4)
samples = []
uvs = mesh.uv_layers.active.data
for loop in mesh.loops:
    uv = uvs[loop.index].uv
    rgb = pixels[min(height - 1, max(0, int(uv.y * height))), min(width - 1, max(0, int(uv.x * width))), :3]
    p = mesh.vertices[loop.vertex_index].co
    samples.append((p.copy(), rgb.copy()))
markers = {}
fractions = [.12, .36, .60, .84]
base_distance = settings['bladeStart'] * LENGTH - grip_from_pommel
tip_distance = LENGTH - grip_from_pommel
tip_points = [v.co.copy() for v in mesh.vertices if v.co.y > tip_distance - .015]
base_points = [v.co.copy() for v in mesh.vertices if abs(v.co.y - base_distance) < .025]
assert tip_points and base_points, 'Blade endpoints not found'
def cross_center(pts):
    return ((min(p.x for p in pts) + max(p.x for p in pts)) * .5,
            (min(p.z for p in pts) + max(p.z for p in pts)) * .5)
tip_x, tip_z = cross_center(tip_points)
base_x, base_z = cross_center(base_points)
box_x, box_z = cross_center([v.co for v in mesh.vertices])
for group in (['Hot', 'Cold'] if args.id == 'Fusion' else ['Shadow']):
    valid = []
    for p, rgb in samples:
        r, g, b = rgb
        match = (r > .48 and r > b * 1.35) if group == 'Hot' else \
                (b > .45 and b > r * 1.3) if group == 'Cold' else \
                (r > .25 and b > .35 and g < max(r, b) * .75)
        if match and p.y > base_distance:
            valid.append(p)
    assert valid, 'No textured surface samples for ' + group
    for i, fraction in enumerate(fractions, 1):
        wanted = base_distance + (tip_distance - base_distance) * fraction
        face = -1 if i % 2 else 1
        candidates = [p for p in valid if abs(p.y - wanted) < .12 and p.x * face > 0]
        if not candidates:
            candidates = valid
        p = min(candidates, key=lambda p: abs(p.y - wanted) * 3 - p.x * face)
        # Blender [thickness, length, width] -> Roblox [thickness, width, -length].
        markers['Aura' + group + str(i)] = [round(p.x + face * .025, 4), round(p.z, 4), round(-p.y, 4)]

bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
fbx = os.path.join(dest, name + '.fbx')
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, axis_forward='-Z', axis_up='Y',
                         apply_unit_scale=True, global_scale=1, path_mode='COPY', embed_textures=True,
                         bake_space_transform=True, mesh_smooth_type='FACE')
import_dir = os.path.join(output, 'A-IMPORTER')
os.makedirs(import_dir, exist_ok=True)
shutil.copyfile(fbx, os.path.join(import_dir, name + '.fbx'))
external_textures = os.path.join(import_dir, name + '.fbm')
os.makedirs(external_textures, exist_ok=True)
for kind in files:
    shutil.copyfile(os.path.join(dest, kind + '.png'), os.path.join(external_textures, kind + '.png'))
info = {
    'id': args.id, 'sourceFile': os.path.basename(src),
    'sourceSha256': hashlib.sha256(open(src, 'rb').read()).hexdigest(),
    'trianglesBefore': before, 'triangles': after,
    'size': [round(span[thick] * scale, 4), round(span[wide] * scale, 4), LENGTH],
    'gripFromPommel': round(grip_from_pommel, 4), 'gripAt': [0, 0, 0],
    'gripCrossOffset': [round(-box_x, 4), round(-box_z, 4)],
    'trailBase': [round(base_x, 4), round(base_z, 4), round(-base_distance, 4)],
    'trailTip': [round(tip_x, 4), round(tip_z, 4), round(-tip_distance, 4)],
    'markers': markers, 'preparation': 'local Blender, source unchanged, no Meshy API calls',
    'robloxImportCompleted': False,
}
with open(os.path.join(dest, 'info.json'), 'w', encoding='utf-8') as handle:
    json.dump(info, handle, indent=2)
print('SWORD_ADDITION', json.dumps(info))

# Side-by-side silhouette/color comparison, actual source vs reduced mesh.
# Rendering uses the same original base-color map, without simulated Roblox FX.
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples, scene.cycles.use_denoising = 12, True
scene.render.resolution_x, scene.render.resolution_y = 1200, 1000
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new('NeutralBackdrop')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.055, .065, .085, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .75
scene.view_settings.view_transform = 'Standard'
# Flat base color is useful here: PBR reflections must not obscure the comparison.
for link in list(bsdf.inputs['Metallic'].links):
    links.remove(link)
bsdf.inputs['Metallic'].default_value = .10
for link in list(bsdf.inputs['Roughness'].links):
    links.remove(link)
bsdf.inputs['Roughness'].default_value = .65
original.hide_render = False
original.location.z, obj.location.z = -1.5, 1.5
cam_data = bpy.data.cameras.new('ComparisonCamera')
cam = bpy.data.objects.new('ComparisonCamera', cam_data)
scene.collection.objects.link(cam)
cam.location = Vector((-9, LENGTH / 2 - grip_from_pommel, 0))
cam.rotation_euler = Matrix(((0, 0, -1), (0, 1, 0), (1, 0, 0))).to_quaternion().to_euler()
cam_data.type, cam_data.ortho_scale = 'ORTHO', 6.6
scene.camera = cam
for label, position in [('Key', (-7, 5, -3)), ('Fill', (-5, 1, 3))]:
    data = bpy.data.lights.new(label, 'AREA')
    data.energy, data.size = 300, 7
    light = bpy.data.objects.new(label, data)
    scene.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (Vector((0, 2, 0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = os.path.join(dest, 'comparaison.png')
bpy.ops.render.render(write_still=True)
