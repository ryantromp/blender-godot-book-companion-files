"""lm_check_assets.py: check every asset of scripts/lm_assets.json that is in the open file.
Run it from the Text Editor (Text > Open, Run Script). It checks the assets that the manifest places in the open file. It writes a table to a new text called check_report and
prints the problems. Checks: triangles against the budget, size against the table, origin on the ground and at the
centre of the footprint, scale 1 and rotation 0, the material of the asset group and its Backface Culling."""
import json
import bpy
from mathutils import Vector

FOLDER = bpy.path.abspath("//")
MANIFEST = json.load(open(FOLDER + "scripts/lm_assets.json"))
THIS_FILE = bpy.path.basename(bpy.data.filepath)  # only assets that live in this file are checked
# Origins that are not at the centre of the footprint on purpose
ORIGIN_OK = {"fence_gate": "hinge edge", "tool_hoe": "foot of the handle", "tree_oak": "trunk", "mach_cart": "between the wheels",
             "an_cow": "middle of the body", "ter_pond": "rim of the pond at Z 0", "gn_fence_line": "start of the curve",
             "gn_scatter": "centre of the tile", "prop_sign_post": "post"}
MATERIALS = {"bld_": "M_farm_ao", "an_": "M_char", "char_": "M_char"}
# Backface Culling per material: off = glTF doubleSided true (single-sided planes show from behind), on = false
CULLING = {"M_farm": False, "M_farm_ao": False, "M_emissive": False, "M_char": True}


def parts_of(root):
    return [root] + [c for c in root.children_recursive if "colonly" not in c.name]


def measure(root):
    dg = bpy.context.evaluated_depsgraph_get()
    tris, pts, mats = 0, [], set()
    for ob in parts_of(root):
        if ob.type != 'MESH':
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        pts += [ob.matrix_world @ v.co for v in me.vertices]
        mats |= {s.material.name for s in ob.material_slots if s.material}
        ev.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return tris, hi - lo, (lo + hi) / 2 - root.matrix_world.translation, lo.z - root.matrix_world.translation.z, mats


def check(e):
    root = bpy.data.objects.get(e["name"])
    if root is None or e["file"] != THIS_FILE:
        return None
    tris, size, centre, low, mats = measure(root)
    bad = []
    if e["tris"] and tris > e["tris"]:
        bad.append("over budget")
    want = [float(v) for v in e["size"].split("x")] if e["size"][:1].isdigit() else None
    if want and e["name"] not in ("gn_scatter", "mach_pump", "mach_windmill") and not e["name"].startswith(("char_", "an_", "crop_")) \
            and max(abs(a - b) for a, b in zip(size, want)) > 0.01:
        bad.append("size")
    if e["name"] not in ORIGIN_OK and (abs(centre.x) > 0.05 or abs(centre.y) > 0.05 or abs(low) > 0.01):
        bad.append("origin off by %.2f, %.2f, %.2f" % (centre.x, centre.y, low))
    if tuple(round(v, 4) for v in root.scale) != (1, 1, 1) or any(abs(a) > 1e-4 for a in root.rotation_euler):
        bad.append("unapplied scale or rotation")
    want_mat = next((m for k, m in MATERIALS.items() if e["name"].startswith(k)), "M_farm")
    if want_mat not in mats:
        bad.append("material should be " + want_mat)
    for name in sorted(mats):
        if name in CULLING and bpy.data.materials[name].use_backface_culling != CULLING[name]:
            bad.append("%s Backface Culling should be %s" % (name, "on" if CULLING[name] else "off"))
    return tris, size, mats, bad


lines = ["%-22s %11s  %-18s %s" % ("asset", "tris/budget", "size (m)", "materials and problems")]
problems = 0
for e in MANIFEST:
    r = check(e)
    if r is None:
        continue
    tris, size, mats, bad = r
    problems += len(bad)
    lines.append("%-22s %5d/%-5d  %4.2f x %4.2f x %4.2f  %s %s" % (e["name"], tris, e["tris"], size.x, size.y, size.z, "+".join(sorted(mats)), "; ".join(bad) or "ok"))
lines.append("%d assets checked, %d problems" % (len(lines) - 1, problems))
text = bpy.data.texts.get("check_report") or bpy.data.texts.new("check_report")
text.clear()
text.write("\n".join(lines) + "\n")
print("\n".join(lines))
