"""lm_rig_animals.py : Chapter 16.  Builds the three hand-made animal rigs of lm_animals.blend and weights them.
For each of an_chicken, an_dog and an_cow it
1. creates an armature <animal>_rig at the animal's location from the bone table below (left side listed, right side mirrored),
2. parents the animal to it with automatic weights,
3. makes the small parts (head parts, paws, hooves, ears) rigid, blends the body along the spine, keeps the automatic weights
   on the legs, tail and neck, removes weights under 0.15, normalizes and keeps at most 4 groups per vertex.
Open lm_animals.blend, open this file in the Text Editor of the Scripting workspace and press Run Script.
Bone names follow PIPELINE.md: root, hips, spine, chest, neck, head, tail, leg_*/paw_*/hoof_*, with .L and .R suffixes.
Local X of every bone points along world X, so a positive X rotation swings a hanging leg backward."""
import bpy, bmesh
from mathutils import Vector

CHICKEN = [
 ('root',      None,       (0, 0.0, 0.0),    (0, 0.0, 0.06)),
 ('spine',     'root',     (0, 0.10, 0.21),  (0, -0.08, 0.23)),
 ('neck',      'spine',    (0, -0.08, 0.23), (0, -0.14, 0.33)),
 ('head',      'neck',     (0, -0.14, 0.33), (0, -0.225, 0.35)),
 ('tail',      'spine',    (0, 0.10, 0.25),  (0, 0.20, 0.33)),
 ('wing.L',    'spine',    (0.09, -0.06, 0.24), (0.10, 0.08, 0.20)),
 ('leg.L',     'spine',    (0.04, 0.0, 0.115), (0.04, 0.0, 0.012)),
 ('foot.L',    'leg.L',    (0.04, 0.0, 0.012), (0.04, -0.06, 0.006)),
]
DOG = [
 ('root',        None,       (0, 0.0, 0.0),     (0, 0.0, 0.10)),
 ('hips',        'root',     (0, 0.28, 0.38),   (0, 0.10, 0.40)),
 ('spine',       'hips',     (0, 0.10, 0.40),   (0, -0.16, 0.42)),
 ('neck',        'spine',    (0, -0.16, 0.42),  (0, -0.30, 0.52)),
 ('head',        'neck',     (0, -0.30, 0.52),  (0, -0.53, 0.52)),
 ('ear.L',       'head',     (0.09, -0.33, 0.57), (0.115, -0.33, 0.43)),
 ('tail',        'hips',     (0, 0.28, 0.416),  (0, 0.38, 0.50)),
 ('tail.001',    'tail',     (0, 0.38, 0.50),   (0, 0.48, 0.584)),
 ('leg_f_upper.L','spine',   (0.075, -0.17, 0.34), (0.075, -0.17, 0.17)),
 ('leg_f_lower.L','leg_f_upper.L', (0.075, -0.17, 0.17), (0.075, -0.17, 0.04)),
 ('paw_f.L',     'leg_f_lower.L', (0.075, -0.17, 0.04), (0.075, -0.24, 0.02)),
 ('leg_h_upper.L','hips',    (0.09, 0.20, 0.36), (0.085, 0.22, 0.17)),
 ('leg_h_lower.L','leg_h_upper.L', (0.085, 0.22, 0.17), (0.085, 0.22, 0.04)),
 ('paw_h.L',     'leg_h_lower.L', (0.085, 0.22, 0.04), (0.085, 0.155, 0.02)),
]
COW = [
 ('root',        None,       (0, 0.0, 0.0),     (0, 0.0, 0.20)),
 ('hips',        'root',     (0, 0.80, 1.00),   (0, 0.35, 1.00)),
 ('spine',       'hips',     (0, 0.35, 1.00),   (0, -0.10, 1.00)),
 ('chest',       'spine',    (0, -0.10, 1.00),  (0, -0.56, 1.00)),
 ('neck',        'chest',    (0, -0.56, 1.00),  (0, -1.00, 1.25)),
 ('head',        'neck',     (0, -1.00, 1.25),  (0, -1.42, 1.08)),
 ('ear.L',       'head',     (0.17, -1.00, 1.27), (0.37, -1.02, 1.25)),
 ('tail',        'hips',     (0, 0.86, 1.03),   (0, 0.86, 0.80)),
 ('tail.001',    'tail',     (0, 0.86, 0.80),   (0, 0.86, 0.55)),
 ('leg_f_upper.L','chest',   (0.20, -0.50, 0.72), (0.20, -0.50, 0.41)),
 ('leg_f_lower.L','leg_f_upper.L', (0.20, -0.50, 0.41), (0.20, -0.50, 0.10)),
 ('hoof_f.L',    'leg_f_lower.L', (0.20, -0.50, 0.10), (0.20, -0.57, 0.02)),
 ('leg_h_upper.L','hips',    (0.20, 0.60, 0.72), (0.20, 0.60, 0.41)),
 ('leg_h_lower.L','leg_h_upper.L', (0.20, 0.60, 0.41), (0.20, 0.60, 0.10)),
 ('hoof_h.L',    'leg_h_lower.L', (0.20, 0.60, 0.10), (0.20, 0.53, 0.02)),
]
RIGS = {'an_chicken': CHICKEN, 'an_dog': DOG, 'an_cow': COW}

PARTS = {
 'an_chicken': [
  ('body',(0,0.02,0.2),'spine'), ('neck',(0,-0.115,0.3),'neck'), ('head',(0,-0.15,0.355),'head'),
  ('beak',(0,-0.225,0.35),'head'), ('comb',(0,-0.145,0.395),'head'), ('wattle',(0,-0.172,0.31),'head'),
  ('tail',(0,0.17,0.3),'tail'), ('leg',(0.04,0,0.0575),'leg.L'), ('foot',(0.04,-0.02,0.006),'foot.L'),
  ('wing',(0.098,0.01,0.21),'wing.L'), ('eye',(0.04,-0.168,0.37),'head')],
 'an_dog': [
  ('body',(0,0.04,0.37),['hips','spine']), ('neck',(0,-0.25,0.46),'neck'), ('collar',(0,-0.245,0.45),'neck'),
  ('head',(0,-0.36,0.53),'head'), ('snout',(0,-0.46,0.5),'head'), ('nose',(0,-0.527,0.515),'head'),
  ('tail',(0,0.38,0.5),None), ('leg_f',(0.075,-0.17,0.17),None), ('paw_f',(0.075,-0.185,0.02),'paw_f.L'),
  ('thigh',(0.095,0.2,0.3),'leg_h_upper.L'), ('leg_h',(0.085,0.22,0.13),None), ('paw_h',(0.085,0.205,0.02),'paw_h.L'),
  ('ear',(0.105,-0.33,0.5),'ear.L'), ('eye',(0.055,-0.42,0.52),'head')],
 'an_cow': [
  ('body',(0,0.1,0.99),['hips','spine','chest']), ('neck',(0,-0.78,1.12),None), ('head',(0,-1.1,1.15),'head'),
  ('muzzle',(0,-1.35,1.07),'head'), ('udder',(0,0.45,0.58),'hips'), ('tail',(0,0.86,0.8),None), ('tuft',(0,0.86,0.5),'tail.001'),
  ('leg_f',(0.2,-0.5,0.41),None), ('hoof_f',(0.2,-0.5,0.05),'hoof_f.L'), ('leg_h',(0.2,0.6,0.41),None), ('hoof_h',(0.2,0.6,0.05),'hoof_h.L'),
  ('ear',(0.27,-1,1.27),'ear.L'), ('horn',(0.12,-1,1.4),'head'), ('eye',(0.165,-1.1,1.27),'head')],
}


def smooth(t): t=max(0.0,min(1.0,t)); return t*t*(3-2*t)

def chain_weights(rig, bones, co, half=0.06):
    """weights of vertex co (object space) along a bone chain: pure inside a bone, smoothstep over +-half around each joint"""
    # parameter: distance along the chain axis (projected on the chain polyline)
    segs=[(rig.data.bones[b].head_local, rig.data.bones[b].tail_local) for b in bones]
    # project onto the first-to-last direction; use each bone's own axis for the joint plane
    pos=[]
    for h,t in segs:
        d=(t-h); L=d.length; d/=L
        pos.append(((co-h).dot(d), L, d))
    # joint k between bone k and k+1: signed distance beyond the plane at the end of bone k (use bone k axis)
    # sequential blend: start fully on bone 0, move to bone 1 after joint 0, etc.
    cur=[1.0]+[0.0]*(len(bones)-1)
    for k in range(len(bones)-1):
        s, L, d = pos[k]
        a = smooth((s-(L-half))/(2*half))      # 0 before the joint zone, 1 after it
        moved = cur[k]*a
        cur[k]-=moved; cur[k+1]+=moved
    return {bones[i]:cur[i] for i in range(len(bones)) if cur[i]>1e-4}


def shells(obj):
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

def mirror_name(n): return n[:-1] + 'R' if n.endswith('.L') else n

def make_rig(animal):
    obj = bpy.data.objects[animal]
    arm = bpy.data.armatures.new(animal + '_rig')
    rig = bpy.data.objects.new(animal + '_rig', arm)
    for c in obj.users_collection: c.objects.link(rig)
    rig.location = obj.location
    bpy.context.view_layer.objects.active = rig
    for o in bpy.data.objects: o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    for name, parent, h, t in RIGS[animal]:
        for nm in ([name] if not name.endswith('.L') else [name, mirror_name(name)]):
            sx = -1 if nm.endswith('.R') else 1
            e = eb.new(nm); e.head = (h[0] * sx, h[1], h[2]); e.tail = (t[0] * sx, t[1], t[2])
            if parent: e.parent = eb[mirror_name(parent) if nm.endswith('.R') else parent]
    for e in eb:                       # local X = world X wherever the bone is not lateral
        d = (e.tail - e.head).normalized()
        if abs(d.x) < 0.5: e.align_roll(Vector((1, 0, 0)).cross(d))
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig

def apply_rules(obj, rig, parts, clean=0.15):
    for comp in shells(obj):
        c = sum((obj.data.vertices[i].co for i in comp), Vector()) / len(comp)
        sx = -1 if c.x < -1e-4 else 1
        part, _, rule = min(parts, key=lambda p: (Vector((p[1][0] * sx, p[1][1], p[1][2])) - c).length)
        if rule is None: continue
        bn = lambda b: b[:-1] + 'R' if (sx < 0 and b.endswith('.L')) else b
        for g in obj.vertex_groups: g.remove(comp)
        if isinstance(rule, str):
            obj.vertex_groups[bn(rule)].add(comp, 1.0, 'REPLACE')
        else:
            bones = [bn(b) for b in rule]
            for i in comp:
                for b, w in chain_weights(rig, bones, obj.data.vertices[i].co).items():
                    obj.vertex_groups[b].add([i], w, 'REPLACE')

for animal in RIGS:
    obj = bpy.data.objects.get(animal)
    if obj is None or animal + '_rig' in bpy.data.objects: continue
    rig = make_rig(animal)
    for o in bpy.data.objects: o.select_set(False)
    obj.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    apply_rules(obj, rig, PARTS[animal])
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.vertex_group_clean(group_select_mode='ALL', limit=0.15, keep_single=True)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    print('lm_rig_animals:', rig.name, len(rig.data.bones), 'bones,', len(obj.vertex_groups), 'groups')
