"""lm_proxies.py: add the collision proxies of Chapter 20 to the .blend file that is open.
Run it from the Text Editor (Text > Open, Run Script). It adds one low-poly mesh per entry of PROXIES, named
<asset>__hull-convcolonly (one convex shape) or <asset>__mesh-colonly (exact triangles), parented to the asset.
Godot reads the ending of the name, turns the mesh into a collision shape and removes the mesh (Chapter 20)."""
import math
import bpy
import bmesh
from mathutils import Vector

# asset: (kind, limits). kind 'hull' = Convex Hull of the chosen vertices, 'mesh' = the object's own faces.
# Limits are in the asset's own space: zmax/zmin/ymin keep vertices inside the range, ground adds a copy of every
# kept vertex at Z 0, parts True also uses the child objects (wheels), False uses the asset object alone.
PROXIES = {
    "bld_farmhouse": ("hull", dict(zmax=4.7)),
    "bld_barn": ("hull", dict()),
    "bld_shed": ("hull", dict()),
    "bld_chicken_coop": ("hull", dict(ymin=-0.31, ground=True)),
    "bld_well": ("hull", dict(zmax=0.71)),
    "fence_post": ("hull", dict()),
    "fence_rail": ("hull", dict()),
    "fence_corner": ("hull", dict()),
    "fence_gate": ("hull", dict()),
    "ter_tile_flat": ("mesh", dict()),
    "ter_tile_slope": ("mesh", dict()),
    "ter_tile_corner": ("mesh", dict()),
    "ter_pond": ("mesh", dict()),
    "rock_a": ("hull", dict()),
    "rock_b": ("hull", dict()),
    "rock_c": ("hull", dict()),
    "cliff_straight": ("hull", dict()),
    "cliff_corner": ("hull", dict()),
    "mach_tractor": ("hull", dict(zmax=1.45, parts=True)),
    "mach_cart": ("hull", dict(ymin=-0.45, parts=True)),
    "mach_windmill": ("hull", dict()),
    "mach_pump": ("hull", dict(zmax=0.9)),
}


# Limited Dissolve angle in degrees: hulls are rounded off, a copied mesh may only lose flat detail
ANGLE = {"hull": 12.0, "mesh": 1.0}


def points_of(root, limits):
    """Vertices of the asset in its own space, filtered by the limits."""
    to_local = root.matrix_world.inverted()
    objs = [root] + (list(root.children_recursive) if limits.get("parts") else [])
    pts = []
    for ob in objs:
        if ob.type != 'MESH' or "colonly" in ob.name:
            continue
        for v in ob.data.vertices:
            p = to_local @ (ob.matrix_world @ v.co)
            if p.z > limits.get("zmax", 1e9) or p.z < limits.get("zmin", -1e9) or p.y < limits.get("ymin", -1e9):
                continue
            pts.append(p)
            if limits.get("ground") and p.z > 0.001:
                pts.append(Vector((p.x, p.y, 0.0)))
    return pts


def make_proxy(root, kind, limits):
    bm = bmesh.new()
    if kind == "hull":
        for p in points_of(root, limits):
            bm.verts.new(p)
        bmesh.ops.convex_hull(bm, input=bm.verts)                                  # Mesh > Convex Hull
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    else:
        bm.from_mesh(root.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(ANGLE[kind]), verts=bm.verts, edges=bm.edges)   # Mesh > Clean Up > Limited Dissolve
    bmesh.ops.triangulate(bm, faces=bm.faces)
    name = root.name + ("__hull-convcolonly" if kind == "hull" else "__mesh-colonly")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    col = bpy.data.collections.get("COL_collision") or bpy.data.collections.new("COL_collision")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
    ob.parent = root
    ob.matrix_world = root.matrix_world.copy()
    ob.display_type = 'WIRE'
    ob.hide_render = True
    return ob


def run():
    made = []
    for asset, (kind, limits) in PROXIES.items():
        root = bpy.data.objects.get(asset)
        if root is None:
            continue
        for old in [o for o in bpy.data.objects if o.name.startswith(root.name + "__") and o.name.endswith(("colonly", "colonly.001", "colonly.002", "colonly.003"))]:
            bpy.data.objects.remove(old)
        made.append(make_proxy(root, kind, limits))
    for ob in made:
        print("proxy", ob.name, len(ob.data.polygons), "tris")
    return made


run()
