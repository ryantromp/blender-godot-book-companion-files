"""lm_vfx_banner.py : Chapter 18.  Builds the banner pole and the banner (a 16 x 10 grid) for the cloth simulation.
Open lm_vfx.blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
vfx_banner_pole : one post 2.6 m tall and a crossbar 1.4 m wide at the top, joined into one mesh, origin at the foot.
vfx_banner      : 1.2 m by 0.8 m, 17 x 11 vertices, hung below the crossbar; the 17 top vertices are the vertex group "pin".
vfx_wind        : a Wind force field 2.8 m in front of the banner, Strength 1000, Noise 1.0, blowing toward +Y (the pole)."""
import math
import bpy
import bmesh
from mathutils import Matrix

POLE_AT = (3.6, 1.0, 1.3)          # centre of the post
BANNER_AT = (3.6, 0.9, 2.05)       # centre of the banner, 0.1 m in front of the post
WIDTH, HEIGHT, COLS, ROWS = 1.2, 0.8, 16, 10


def add_object(name, mesh, location):
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.location = location
    return ob


def pole_mesh():
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.04, radius2=0.04, depth=2.6)
    bar = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.03, radius2=0.03, depth=1.4)["verts"]
    bmesh.ops.rotate(bm, verts=bar, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'Y'))
    bmesh.ops.translate(bm, verts=bar, vec=(0, 0, 1.15))      # 1.3 + 1.15 = 2.45 m, the top edge of the banner
    me = bpy.data.meshes.new("vfx_banner_pole")
    bm.to_mesh(me)
    bm.free()
    return me


def banner_mesh():
    bm = bmesh.new()
    grid = [[bm.verts.new((-WIDTH / 2 + WIDTH * i / COLS, 0.0, HEIGHT / 2 - HEIGHT * j / ROWS))
             for i in range(COLS + 1)] for j in range(ROWS + 1)]
    for j in range(ROWS):
        for i in range(COLS):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("vfx_banner")
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")                       # a flat 0 to 1 map, Chapter 9 re-fits it
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x / WIDTH + 0.5, co.z / HEIGHT + 0.5)
    return me


def wind_object():
    bpy.ops.object.effector_add(type='WIND', location=(3.6, -1.9, 2.05), rotation=(math.radians(-90), 0.0, 0.0))
    ob = bpy.context.active_object
    ob.name = "vfx_wind"
    ob.field.strength = 1000.0
    ob.field.noise = 1.0
    return ob


pole = add_object("vfx_banner_pole", pole_mesh(), POLE_AT)
banner = add_object("vfx_banner", banner_mesh(), BANNER_AT)
pin = banner.vertex_groups.new(name="pin")
top = [v.index for v in banner.data.vertices if v.co.z > HEIGHT / 2 - 0.01]
pin.add(top, 1.0, 'REPLACE')
wind_object()
print("pole:", len(pole.data.vertices), "vertices;", "banner:", len(banner.data.vertices), "vertices,",
      len(banner.data.polygons), "faces, pinned", len(top))
