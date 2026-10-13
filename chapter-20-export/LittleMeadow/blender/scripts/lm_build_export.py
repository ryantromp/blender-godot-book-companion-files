"""lm_build_export.py: collect every asset of the game into the open file, one child collection of COL_export each.
Run it in a saved file that sits in LittleMeadow/blender/ (Text > Open, Run Script). It reads scripts/lm_assets.json,
appends each asset with its parts, collision proxies and rig, merges duplicate materials and images, sets Backface Culling of the four materials, names the mesh
data like the object, removes unused data, gives every asset one root object and lines the assets up in rows."""
import json
import bpy
from mathutils import Vector

FOLDER = bpy.path.abspath("//")
MANIFEST = json.load(open(FOLDER + "scripts/lm_assets.json"))
# Backface Culling per material: off = glTF doubleSided true, on = false (the checker and verify_export.py test it too)
CULLING = {"M_farm": False, "M_farm_ao": False, "M_emissive": False, "M_char": True}


def wanted(names, entry):
    """Object names that belong to one asset: itself, its parts (asset__part), its proxies and its rig."""
    if "objects" in entry:
        return entry["objects"]
    a = entry["name"]
    return [n for n in names if n == a or n == a + "_rig" or n.startswith(a + "__")]


def append_assets():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    top = bpy.data.collections.new("COL_export")
    bpy.context.scene.collection.children.link(top)
    for src in dict.fromkeys(e["file"] for e in MANIFEST):
        entries = [e for e in MANIFEST if e["file"] == src]
        with bpy.data.libraries.load(FOLDER + src, link=False) as (data_from, data_to):
            picks = {e["name"]: wanted(data_from.objects, e) for e in entries}
            names = sorted({n for p in picks.values() for n in p})
            data_to.objects = list(names)
        loaded = dict(zip(names, data_to.objects))
        for e in entries:
            coll = bpy.data.collections.new(e["name"])
            top.children.link(coll)
            for n in picks[e["name"]]:
                coll.objects.link(loaded[n])


def tidy():
    for ob in bpy.data.objects:
        if ob.type == 'ARMATURE':
            for pb in ob.pose.bones:
                pb.custom_shape = None                      # the Rigify shapes are not needed in the game
        if ob.data and ob.data.users == 1:
            ob.data.name = ob.name                          # mesh data named like its object
    for kind in (bpy.data.materials, bpy.data.images):
        for item in list(kind):
            base = item.name.rsplit(".", 1)[0]
            if base != item.name and item.name[-3:].isdigit() and base in kind:
                item.user_remap(kind[base])                 # M_farm.001 becomes M_farm
                kind.remove(item)
    for name, culling in CULLING.items():
        if name in bpy.data.materials:
            bpy.data.materials[name].use_backface_culling = culling
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def single_root():
    """Every asset gets one root object, so the glb origin is the asset origin: a loose part is parented to the asset
    object, and a set of props without a main object gets an Empty named like the collection."""
    for coll in bpy.data.collections["COL_export"].children:
        roots = [o for o in coll.objects if o.parent is None]
        if len(roots) < 2:
            continue
        main = bpy.data.objects.get(coll.name)
        if main not in roots:
            pts = [o.matrix_world @ Vector(c) for o in roots if o.type == 'MESH' for c in o.bound_box]
            main = bpy.data.objects.new(coll.name, None)
            main.location = ((min(p.x for p in pts) + max(p.x for p in pts)) / 2, (min(p.y for p in pts) + max(p.y for p in pts)) / 2, 0.0)
            coll.objects.link(main)
            bpy.context.view_layer.update()
        for o in roots:
            if o is not main:
                o.parent = main
                o.matrix_parent_inverse = main.matrix_world.inverted()


def lay_out():
    x = y = row_depth = 0.0
    last = None
    for coll in bpy.data.collections["COL_export"].children:
        meshes = [o for o in coll.objects if o.type == 'MESH' and "colonly" not in o.name]
        pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), 0.0))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), 0.0))
        src = next(e["file"] for e in MANIFEST if e["name"] == coll.name)
        if src != last:                                     # a new row for each source file
            x, y, row_depth, last = 0.0, y + row_depth + 3.0, 0.0, src
        for o in coll.objects:
            if o.parent is None:
                o.location += Vector((x, y, 0.0)) - lo
        x += hi.x - lo.x + 1.0
        row_depth = max(row_depth, hi.y - lo.y)
    bpy.context.view_layer.update()


append_assets()
tidy()
single_root()
lay_out()
print("COL_export:", len(bpy.data.collections["COL_export"].children), "assets")
