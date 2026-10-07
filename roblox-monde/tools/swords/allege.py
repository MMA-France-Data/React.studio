# Allege n importe quel modele telecharge (GLB ou FBX avec ses textures dedans) pour Roblox, et rend une image de
# controle. Reglages par variables d environnement :
#   MODELE = chemin du fichier source ; NOM = nom du fichier de sortie (sans .fbx) ; HAUTEUR = hauteur en studs.
#   blender --background --python tools/swords/allege.py
# Ecrit assets/swords-roblox/A-IMPORTER/<NOM>.fbx (au plus 19 000 triangles, textures 1024 dans le FBX, pose au sol,
# debout) et assets/swords-roblox/apercu-<NOM>.png. La source n est pas modifiee.
import bpy, os
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'swords-roblox')
# MORCEAUX : le modele est coupe en autant de morceaux (Roblox limite chaque morceau a 20 000 triangles : trois
# morceaux = trois fois plus de details).
PARTS = int(os.environ.get('MORCEAUX', '1'))
SOURCE, NAME, HEIGHT, TARGET = os.environ['MODELE'], os.environ['NOM'], float(os.environ.get('HAUTEUR', '13')), 19000 * PARTS
bpy.ops.wm.read_factory_settings(use_empty=True)
if SOURCE.lower().endswith('.glb') or SOURCE.lower().endswith('.gltf'):
    bpy.ops.import_scene.gltf(filepath=SOURCE)
else:
    bpy.ops.import_scene.fbx(filepath=SOURCE)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
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
obj.name = mesh.name = NAME
# Les textures : reduites a 1024 et enregistrees a cote, pour etre rangees dans le FBX.
for index, image in enumerate([i for i in bpy.data.images if i.size[0] > 0]):
    if max(image.size) > 1024:
        image.scale(1024, 1024)
    image.filepath_raw = os.path.join(OUT, '%s-texture%d.png' % (NAME, index)); image.file_format = 'PNG'; image.save()
os.makedirs(os.path.join(OUT, 'A-IMPORTER'), exist_ok=True)
# Coupe en morceaux : des tranches de gauche a droite, avec le meme nombre de triangles chacune.
pieces = [obj]
if PARTS > 1:
    import bmesh
    order = sorted(range(len(mesh.polygons)), key=lambda i: mesh.polygons[i].center.x)
    group = {}
    for rank, index in enumerate(order):
        group[index] = min(PARTS - 1, rank * PARTS // len(order))
    pieces = []
    for part in range(PARTS):
        copy = obj.copy(); copy.data = mesh.copy(); bpy.context.scene.collection.objects.link(copy)
        bm = bmesh.new(); bm.from_mesh(copy.data); bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if group[f.index] != part], context='FACES')
        bm.to_mesh(copy.data); bm.free()
        copy.name = copy.data.name = '%s_%d' % (NAME, part + 1)
        pieces.append(copy)
    bpy.data.objects.remove(obj)
bpy.ops.object.select_all(action='DESELECT')
for piece in pieces:
    piece.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, 'A-IMPORTER', NAME + '.fbx'), use_selection=True, axis_forward='-Z', axis_up='Y', apply_unit_scale=True, path_mode='COPY', embed_textures=True, bake_space_transform=True, mesh_smooth_type='FACE')
print('MODELE %s : triangles %d -> %d ; taille (x, y, hauteur) %.1f %.1f %.1f ; matieres %d' % (NAME, before, sum(sum(len(p.vertices) - 2 for p in piece.data.polygons) for piece in pieces), size.x, size.y, size.z, len(pieces[0].data.materials)))
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(size.x, size.y, size.z) * 1.5
camera = bpy.data.objects.new('cam', cam); bpy.context.scene.collection.objects.link(camera)
camera.location = (14, -22, 14)
bpy.context.scene.camera = camera
target = bpy.data.objects.new('t', None); target.location = (0, 0, HEIGHT / 2); bpy.context.scene.collection.objects.link(target)
track = camera.constraints.new('TRACK_TO'); track.target = target
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'; scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
scene.render.filepath = os.path.join(OUT, 'apercu-%s.png' % NAME)
bpy.ops.render.render(write_still=True)
print('RENDU')
