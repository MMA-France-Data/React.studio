# Allège les épées Meshy pour Roblox (limite : 20 000 triangles par mesh) et les met dans le bon repère.
#   blender --background --python tools/swords/optimise.py
# Pour chaque épée de assets/swords-meshy/<Nom>/Sword_<Nom>.fbx, écrit dans assets/swords-roblox/<Nom>/ :
#   Sword_<Nom>.fbx : au plus TARGET triangles, mêmes UV (les textures d'origine s'appliquent telles quelles),
#                     lame le long de -Z, poignée à l'origine, longueur totale LENGTH studs ;
#   info.json       : triangles, dimensions, et où sont le bas et la pointe de la lame (pour TrailBase / TrailTip).
# Les fichiers d'origine ne sont jamais modifiés.
import bpy, json, os, sys
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC, OUT = os.path.join(ROOT, 'assets', 'swords-meshy'), os.path.join(ROOT, 'assets', 'swords-roblox')
NAMES = ['Iron', 'Steel', 'Gold', 'Frost', 'Flame', 'Storm', 'Prismatic']
TARGET = 14000   # triangles au plus
LENGTH = 5.2     # longueur totale de l'épée, en studs
FLIP = {'Gold'}

report = {}
QA = {m['id']: m['textures'] for m in json.load(open(os.path.join(SRC, 'IMPORT_QA.json'), encoding='utf-8'))['models']}
for name in NAMES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, name, 'Sword_%s.fbx' % name))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = obj.data
    before = sum(len(p.vertices) - 2 for p in mesh.polygons)

    # 1. Alléger, en gardant les UV.
    if before > TARGET:
        mod = obj.modifiers.new('Decimate', 'DECIMATE')
        mod.ratio = TARGET / before
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh = obj.data
    after = sum(len(p.vertices) - 2 for p in mesh.polygons)

    # 2. Le repère : l'axe le plus long devient la longueur ; le plus petit, l'épaisseur.
    points = [v.co.copy() for v in mesh.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    size = hi - lo
    axes = sorted(range(3), key=lambda i: size[i])          # [épaisseur, largeur, longueur]
    thick, wide, long = axes
    # La poignée est du côté le plus ÉTROIT (la lame est plus large que le manche... sauf la garde : on compare
    # donc la largeur moyenne du premier et du dernier quart).
    def mean_width(a, b):
        sel = [p for p in points if a <= (p[long] - lo[long]) / size[long] <= b]
        return sum(abs(p[wide] - (lo[wide] + hi[wide]) / 2) for p in sel) / max(1, len(sel))
    grip_low = mean_width(0.0, 0.18) < mean_width(0.82, 1.0)   # la poignée est-elle du côté des petites valeurs ?
    if name in FLIP:   # (vérifié sur l'aperçu : la règle se trompe pour cette épée, dont la pointe est très fine)
        grip_low = not grip_low
    scale = LENGTH / size[long]
    # Roblox : X = épaisseur, Y = largeur, -Z = vers la pointe. Dans Blender (Z vers le haut), l'export FBX avec
    # axis_forward='-Z', axis_up='Y' garde ces axes tels quels.
    center = (lo + hi) / 2
    sign = 1 if grip_low else -1
    for v in mesh.vertices:
        p = v.co
        along = (p[long] - (lo[long] if grip_low else hi[long])) * sign   # 0 au pommeau, + vers la pointe
        v.co = Vector(((p[thick] - center[thick]) * scale, (p[wide] - center[wide]) * scale, -along * scale))
    if sign < 0 or (thick, wide, long) not in ((0, 1, 2), (1, 2, 0), (2, 0, 1)):
        # Le changement d'axes a pu retourner les faces : on recalcule les normales vers l'extérieur.
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
    mesh.update()

    # 3. Où est la garde ? Là où l'épée est la plus large, dans la première moitié. La poignée (le milieu entre
    # le pommeau et la garde) est mise à l'origine ; la lame va de la garde à la pointe.
    points = [v.co.copy() for v in mesh.vertices]
    slices = 60
    widths = [0.0] * slices
    for p in points:
        i = min(slices - 1, int(-p.z / LENGTH * slices))
        widths[i] = max(widths[i], abs(p.y))
    guard_slice = max(range(3, slices // 2), key=lambda i: widths[i])
    guard = (guard_slice + 0.5) / slices * LENGTH
    grip = guard * 0.5
    for v in mesh.vertices:
        v.co.z += grip
    mesh.update()
    obj.name = 'Sword_' + name
    mesh.name = 'Sword_' + name

    os.makedirs(os.path.join(OUT, name), exist_ok=True)
    # 4. La matière : les quatre textures d'origine, réduites à 1024 (la taille que Roblox garde) et RANGÉES DANS LE
    # FBX, pour que l'importeur de Studio les prenne tout seul (couleur, relief, métal, rugosité).
    maps = QA[name]
    mat = bpy.data.materials.new('Sword_' + name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes['Principled BSDF']
    def texture(kind, colour):
        image = bpy.data.images.load(os.path.join(SRC, maps[kind]['file']))
        image.scale(1024, 1024)
        image.filepath_raw = os.path.join(OUT, name, kind + '.png')
        image.file_format = 'PNG'
        image.save()
        node = nodes.new('ShaderNodeTexImage')
        node.image = image
        if not colour:
            image.colorspace_settings.name = 'Non-Color'
        return node
    links.new(texture('baseColor', True).outputs['Color'], bsdf.inputs['Base Color'])
    links.new(texture('metallic', False).outputs['Color'], bsdf.inputs['Metallic'])
    links.new(texture('roughness', False).outputs['Color'], bsdf.inputs['Roughness'])
    bump = nodes.new('ShaderNodeNormalMap')
    links.new(texture('normal', False).outputs['Color'], bump.inputs['Color'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    mesh.materials.clear()
    mesh.materials.append(mat)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name, 'Sword_%s.fbx' % name), use_selection=True, axis_forward='-Z', axis_up='Y', apply_unit_scale=True, global_scale=1.0, path_mode='COPY', embed_textures=True, bake_space_transform=True, mesh_smooth_type='FACE')
    info = {
        'trianglesBefore': before, 'triangles': after,
        'size': [round(size[thick] * scale, 3), round(size[wide] * scale, 3), LENGTH],
        'gripAt': [0, 0, 0],
        'trailBase': [0, 0, round(-(guard - grip) - 0.25, 3)],
        'trailTip': [0, 0, round(-(LENGTH - grip), 3)],
        'gripWasAtLowEnd': grip_low,
    }
    json.dump(info, open(os.path.join(OUT, name, 'info.json'), 'w'), indent=1)
    report[name] = info
    print('EPEE', name, json.dumps(info))

json.dump(report, open(os.path.join(OUT, 'RAPPORT.json'), 'w'), indent=1)
print('TERMINE')
