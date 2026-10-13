"""lm_build_veg.py : Chapter 11.  Builds the three flowers and the twelve crop growth stages of lm_vegetation.blend.
You model flower A and the carrot by hand in the chapter; this script builds all of them the same way (primitives, join,
Shade Flat, origin at the base) so you get the exact set.  Open lm_vegetation.blend, open this file in the Text Editor of
the Scripting workspace and press Run Script.  Objects land in the active collection (COL_vegetation)."""
import math
import bpy, bmesh
from mathutils import Vector, Euler

def ctx(): return bpy.context.temp_override()
def active(): return bpy.context.view_layer.objects.active
def select_only(*objs, act=None):
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for o in bpy.data.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = act or objs[-1]

def add(kind, loc=(0, 0, 0), name=None, rot=(0, 0, 0), **kw):
    if kind == 'cone': bpy.ops.mesh.primitive_cone_add(location=loc, **kw)
    elif kind == 'cyl': bpy.ops.mesh.primitive_cylinder_add(location=loc, **kw)
    elif kind == 'ico': bpy.ops.mesh.primitive_ico_sphere_add(location=loc, **kw)
    elif kind == 'uv': bpy.ops.mesh.primitive_uv_sphere_add(location=loc, **kw)
    elif kind == 'plane': bpy.ops.mesh.primitive_plane_add(location=loc, **kw)
    elif kind == 'circle': bpy.ops.mesh.primitive_circle_add(location=loc, **kw)
    elif kind == 'cube': bpy.ops.mesh.primitive_cube_add(location=loc, **kw)
    o = active()
    if rot != (0, 0, 0): o.rotation_euler = tuple(math.radians(a) for a in rot)
    if name: o.name = name; o.data.name = name
    return o

def apply_xf(o, loc=False, rot=True, scale=True):
    select_only(o)
    bpy.ops.object.transform_apply(location=loc, rotation=rot, scale=scale)

def join(objs, base, name=None):
    select_only(*objs, base, act=base)
    bpy.ops.object.join()
    if name: base.name = name; base.data.name = name
    return base

def set_dims(o, dims):
    bpy.context.view_layer.update()
    o.dimensions = dims
    apply_xf(o, rot=False)

def flat(o):
    select_only(o); bpy.ops.object.shade_flat()

def origin_to(o, pt=(0, 0, 0)):
    """Origin to a world point (cursor then Origin to 3D Cursor)."""
    bpy.context.scene.cursor.location = pt
    select_only(o); bpy.ops.object.origin_set(type='ORIGIN_CURSOR', center='MEDIAN')
    bpy.context.scene.cursor.location = (0, 0, 0)

def bbox(o):
    bpy.context.view_layer.update()
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))), Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))

def ground(o, cx=None, cy=None):
    """put the object's origin at the base centre (bbox x/y centre, z min) and the object at (0,0,0)"""
    mn, mx = bbox(o)
    origin_to(o, ((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    o.location = (0, 0, 0)

def stats(o):
    dg = bpy.context.evaluated_depsgraph_get(); e = o.evaluated_get(dg); me = e.to_mesh(); me.calc_loop_triangles()
    r = dict(verts=len(me.vertices), tris=len(me.loop_triangles)); e.to_mesh_clear(); return r

def edit_select(o, pred, mode='VERT'):
    select_only(o)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_mode(type=mode)
    bpy.ops.mesh.select_all(action='DESELECT')
    bm = bmesh.from_edit_mesh(o.data); bm.verts.ensure_lookup_table()
    n = 0
    for v in bm.verts:
        if pred(v.co): v.select_set(True); n += 1
    bm.select_flush_mode(); bmesh.update_edit_mesh(o.data)
    return n

# ---------------------------------------------------------------- flowers
def stem(h=0.2, r=0.012, z0=0.0):
    return add('cyl', (0, 0, z0 + h / 2), vertices=4, radius=r, depth=h)

def blade(w, h, tilt_deg=0, yaw_deg=0, loc=(0, 0, 0), face='side', taper=0.25):
    """A flat blade standing on z=0: a plane stood up, narrowed at the top (2 triangles), leaned by tilt_deg
    toward +X (or toward the front for face='side'), turned yaw_deg about Z and moved to loc."""
    p = add('plane', (0, 0, 0), size=1)
    p.rotation_euler = (math.radians(90), 0, 0) if face == 'side' else (0, math.radians(90), 0)
    apply_xf(p)
    for v in p.data.vertices:
        top = v.co.z > 0
        if face == 'side': v.co.x *= w * (taper if top else 1.0); v.co.z = h if top else 0
        else: v.co.y *= w * (taper if top else 1.0); v.co.z = h if top else 0
    p.rotation_euler = (0, math.radians(tilt_deg), math.radians(yaw_deg)); p.location = loc
    apply_xf(p, loc=True)
    return p

def leaf(loc, w, h, tilt_deg, yaw_deg):
    return blade(w, h, tilt_deg, yaw_deg, loc, 'side', 0.25)

def flower_a(loc=(0, 0, 0)):
    s = stem(0.2)
    head = add('cone', (0, 0, 0.215), vertices=8, radius1=0.075, radius2=0.0, depth=0.03)
    ctr = add('cone', (0, 0, 0.23), vertices=6, radius1=0.03, radius2=0.02, depth=0.025)
    l1 = leaf((0, 0, 0.02), 0.04, 0.09, 55, 0); l2 = leaf((0, 0, 0.02), 0.04, 0.09, 55, 180)
    join([head, ctr, l1, l2], s, 'flower_a'); set_dims(s, (0.15, 0.15, 0.3)); flat(s); ground(s); s.location = loc; return s

def flower_b(loc=(0, 0, 0)):
    s = stem(0.21)
    cup = add('cone', (0, 0, 0.255), vertices=6, radius1=0.0, radius2=0.06, depth=0.09)
    l1 = leaf((0, 0, 0.02), 0.045, 0.13, 70, 0); l2 = leaf((0, 0, 0.02), 0.045, 0.13, 70, 180)
    join([cup, l1, l2], s, 'flower_b'); set_dims(s, (0.15, 0.15, 0.3)); flat(s); ground(s); s.location = loc; return s

def flower_c(loc=(0, 0, 0)):
    s = stem(0.2)
    parts = []
    for i, (r, z) in enumerate([(0.05, 0.215), (0.042, 0.255), (0.034, 0.29)]):
        parts.append(add('cone', (0, 0, z), vertices=5, radius1=r, radius2=0.0 if i == 2 else r * 0.8, depth=0.07 if i < 2 else 0.06))
    l1 = leaf((0, 0, 0.02), 0.04, 0.12, 62, 90); l2 = leaf((0, 0, 0.02), 0.04, 0.12, 62, 270)
    join(parts + [l1, l2], s, 'flower_c'); set_dims(s, (0.15, 0.15, 0.3)); flat(s); ground(s); s.location = loc; return s

# ---------------------------------------------------------------- crops
def mound(r=0.13, h=0.05, name=None):
    return add('cone', (0, 0, h / 2), name, vertices=8, radius1=r, radius2=r * 0.45, depth=h)

def finish(o, name, dims=None):
    o.name = name; o.data.name = name
    if dims: set_dims(o, dims)
    flat(o); ground(o); return o

def carrot(stage, loc=(0, 0, 0)):
    if stage == 0:
        return finish(mound(0.12, 0.05), 'crop_carrot_s0', None)
    m = mound(0.12 if stage < 3 else 0.14, 0.05)
    parts = []
    if stage == 1:
        parts = [blade(0.03, 0.09, 12, a, (0.015, 0, 0.04), 'out', 0.3) for a in (0, 180)]
        for p in parts: p.rotation_euler = (0, 0, 0)
    if stage == 2:
        parts = [blade(0.045, 0.2, 22, a, (0.02, 0, 0.04), 'out', 0.3) for a in (0, 72, 144, 216, 288)]
    if stage == 3:
        parts = [blade(0.05, 0.31, 28, a, (0.03, 0, 0.06), 'out', 0.3) for a in (0, 51, 103, 154, 206, 257, 309)]
        root = add('cone', (0, 0, 0.075), vertices=6, radius1=0.05, radius2=0.025, depth=0.05)
        parts.append(root)
    join(parts, m)
    return finish(m, 'crop_carrot_s%d' % stage, (0.3, 0.3, 0.35) if stage == 3 else None)

def wheat(stage, loc=(0, 0, 0)):
    if stage == 0:
        return finish(mound(0.15, 0.05), 'crop_wheat_s0')
    m = mound(0.15, 0.05)
    if stage == 1: n, h, w = 3, 0.12, 0.03
    elif stage == 2: n, h, w = 6, 0.4, 0.035
    else: n, h, w = 7, 0.9, 0.03
    blades = []
    for i in range(n):
        a = i * 360.0 / n
        blades.append(blade(w, h, 8 if stage < 3 else 12, a, (0.06, 0, 0.04), 'out', 0.25))
        if stage == 3:   # the ear: a pointed diamond near the top, leaning with the stalk
            ear = blade(0.07, 0.16, 12, a, (0.06 + 0.9 * math.sin(math.radians(12)) * 0.85, 0, 0.04 + 0.78), 'out', 0.0)
            blades.append(ear)
    join(blades, m)
    return finish(m, 'crop_wheat_s%d' % stage, (0.4, 0.4, 0.9) if stage == 3 else None)

def pumpkin(stage, loc=(0, 0, 0)):
    if stage == 0:
        return finish(mound(0.16, 0.05), 'crop_pumpkin_s0')
    parts = []
    m = mound(0.16, 0.05)
    def pleaf(r, x, y, z, yaw, tilt):
        c = add('circle', (0, 0, 0), vertices=6, radius=r, fill_type='TRIFAN')
        c.rotation_euler = (math.radians(tilt), 0, math.radians(yaw)); c.location = (x, y, z); apply_xf(c, loc=True); return c
    if stage == 1:
        parts = [pleaf(0.06, 0.07, 0, 0.07, 0, 25), pleaf(0.06, -0.07, 0.02, 0.07, 180, 25)]
    if stage == 2:
        parts = [pleaf(0.11, 0.15, 0, 0.1, 0, 20), pleaf(0.11, -0.12, 0.1, 0.1, 140, 20), pleaf(0.1, -0.05, -0.15, 0.1, 250, 20)]
        pk = add('uv', (0.04, 0, 0.1), segments=8, ring_count=4, radius=0.09); pk.scale = (1, 1, 0.8); apply_xf(pk)
        parts.append(pk)
    if stage == 3:
        pk = add('uv', (0, 0, 0.22), segments=10, ring_count=6, radius=0.28); pk.scale = (1, 1, 0.78); apply_xf(pk)
        st = add('cyl', (0, 0, 0.45), vertices=5, radius=0.035, depth=0.1)
        parts = [pk, st, pleaf(0.12, 0.33, 0, 0.1, 0, 20), pleaf(0.12, -0.3, 0.15, 0.1, 150, 20)]
        m_obj = pk
        join(parts[1:], pk); bpy.data.objects.remove(m, do_unlink=True)
        return finish(pk, 'crop_pumpkin_s3', (0.7, 0.7, 0.5))
    join(parts, m)
    return finish(m, 'crop_pumpkin_s%d' % stage)



def run():
    out = []
    for i, f in enumerate([flower_a, flower_b, flower_c]):
        out.append(f((12 + i * 0.6, 0, 0)))
    for r, f in enumerate([carrot, wheat, pumpkin]):
        for st in range(4):
            o = f(st); o.location = (2 + st * 1.2, 3 + r * 1.4, 0); out.append(o)
    return out


if __name__ == '__main__':
    objs = run()
    for o in objs:
        print(o.name, stats(o), [round(d, 3) for d in o.dimensions])
