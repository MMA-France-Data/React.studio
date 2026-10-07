"""Read-only check of the exported FBXs, not just their JSON reports."""
import bpy
import json
import os
from mathutils import Vector

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
for identity in ['Fusion', 'Void']:
    directory = os.path.join(root, 'assets/swords-roblox', identity)
    with open(os.path.join(directory, 'info.json'), encoding='utf-8') as handle:
        info = json.load(handle)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(directory, 'Sword_' + identity + '.fbx'))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    assert len(meshes) == 1, 'Unexpected number of mesh parts'
    obj = meshes[0]
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    assert triangles == info['triangles'] and triangles <= 19000
    assert obj.data.uv_layers.active, 'UVs absent after FBX round-trip'
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    low, high = min(p.y for p in points), max(p.y for p in points)
    assert abs(high - low - 5.2) < .015, 'Length/orientation differs after FBX round-trip'
    grip_points = [p for p in points if abs(p.y) < .09]
    for axis in [0, 2]:
        center = (min(p[axis] for p in grip_points) + max(p[axis] for p in grip_points)) * .5
        assert abs(center) < .035, 'Handle not centered on the hand pivot'
    worst = 0
    for marker, position in info['markers'].items():
        p = Vector((position[0], -position[2], position[1]))
        distance = min((p - v).length for v in points)
        worst = max(worst, distance)
        assert distance < .07, 'Wisp point too far from colored blade surface: ' + marker
    mats = [m for m in obj.data.materials if m and m.use_nodes]
    assert mats, 'No material after FBX round-trip'
    textures = [n.image for m in mats for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
    assert len(textures) >= 4, 'Incomplete PBR maps after FBX round-trip'
    for image in textures:
        assert max(image.size) <= 1024, 'Oversized PBR map'
    print('FBX_ROUND_TRIP_OK', identity, triangles, 'UV/PBR/handle/markers', round(worst, 5))
