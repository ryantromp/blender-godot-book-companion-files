"""lm_rig_weights.py : Chapter 16.  Cleans the automatic weights of char_farmer.
Run it after Ctrl+P > With Automatic Weights has parented char_farmer to char_farmer_rig.  The farmer is a set of closed
shells (head, hat, bib, torso, arms, legs, ...).  Automatic weights let a few shells bleed onto the wrong bones, so:
1. the head, hat, face, hair, bib and straps are made rigid (weight 1.0 on one bone),
2. every other shell keeps the automatic weights,
3. weights under 0.1 are removed, each vertex keeps at most 4 groups (what glTF stores), and the rest is normalized.
It also sets every pose bone of the rig to XYZ Euler rotation (the pose tables of Chapter 17 are in degrees) and switches
both arms to FK (IK_FK = 1.0); the legs stay IK.
Open this file in the Text Editor of the Scripting workspace and press Run Script."""
import bpy, bmesh
from mathutils import Vector

RIGID = [   # part, Location column of Chapter 14, bone.  Parts not listed keep the automatic weights.
 ('head', (0, 0, 1.485), 'DEF-spine.006'), ('nose', (0, -0.143, 1.485), 'DEF-spine.006'),
 ('mouth', (0, -0.132, 1.43), 'DEF-spine.006'), ('hair_back', (0, 0.11, 1.52), 'DEF-spine.006'),
 ('hat_brim', (0, 0, 1.54), 'DEF-spine.006'), ('hat_crown', (0, 0, 1.615), 'DEF-spine.006'),
 ('eye', (0.055, -0.133, 1.51), 'DEF-spine.006'), ('sideburn', (0.118, -0.05, 1.525), 'DEF-spine.006'),
 ('ear', (0.125, 0, 1.485), 'DEF-spine.006'),
 ('bib', (0, -0.1455, 1.18), 'DEF-spine.003'), ('strap_front', (0.09, -0.1455, 1.26), 'DEF-spine.003'),
 ('strap_back', (0.09, 0.1455, 1.26), 'DEF-spine.003'),
 ('neck', (0, 0, 1.36), None), ('torso', (0, 0, 1.04), None), ('leg', (0.105, 0, 0.44), None),
 ('boot', (0.105, 0, 0.095), None), ('toe', (0.105, -0.105, 0.05), None), ('arm', (0.299, 0, 1.056), None),
 ('hand', (0.407, 0, 0.76), None), ('thumb', (0.398, -0.066, 0.783), None)]

def shells(obj):
    """vertex index lists, one per loose shell"""
    bm = bmesh.new(); bm.from_mesh(obj.data); bm.verts.ensure_lookup_table()
    seen = set(); out = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; comp = []; seen.add(v.index)
        while stack:
            x = stack.pop(); comp.append(x.index)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); stack.append(o)
        out.append(comp)
    bm.free()
    return out

farmer = bpy.data.objects['char_farmer']
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
n_rigid = 0
for comp in shells(farmer):
    c = sum((farmer.data.vertices[i].co for i in comp), Vector()) / len(comp)
    sx = -1 if c.x < -1e-4 else 1                      # right side: look up the mirrored Location
    part, _, bone = min(RIGID, key=lambda p: (Vector((p[1][0] * sx, p[1][1], p[1][2])) - c).length)
    if bone is None: continue
    for g in farmer.vertex_groups: g.remove(comp)
    farmer.vertex_groups[bone].add(comp, 1.0, 'REPLACE')
    n_rigid += 1
bpy.context.view_layer.objects.active = farmer
bpy.ops.object.vertex_group_clean(group_select_mode='ALL', limit=0.1, keep_single=True)
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
print('lm_rig_weights: %d shells made rigid' % n_rigid)
rig = bpy.data.objects['char_farmer_rig']
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'
for side in 'LR':
    rig.pose.bones['upper_arm_parent.' + side]['IK_FK'] = 1.0
