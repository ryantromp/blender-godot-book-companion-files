"""lm_fit_metarig.py : Chapter 16.  Fits the Rigify Basic Human metarig to char_farmer.
Add the metarig first (Add > Armature > Rigify Meta-Rigs > Basic > Basic Human), then open this file in the Text Editor of
the Scripting workspace and press Run Script.  It renames the metarig to char_farmer_metarig, deletes the pelvis and breast
bones, moves every bone head and tail to the farmer's joints (left side listed, right side mirrored), and sets the arms and
legs to one segment so the rig keeps one deform bone per limb part.  Values are metres, the farmer faces -Y."""
import bpy

FIT = {   # bone: (head, tail)
 'spine':       ((0, 0.01, 0.74), (0, 0.0, 0.86)),
 'spine.001':   ((0, 0.0, 0.86),  (0, 0.0, 0.98)),
 'spine.002':   ((0, 0.0, 0.98),  (0, 0.0, 1.12)),
 'spine.003':   ((0, 0.0, 1.12),  (0, 0.0, 1.30)),
 'spine.004':   ((0, 0.0, 1.30),  (0, 0.0, 1.37)),
 'spine.005':   ((0, 0.0, 1.37),  (0, 0.0, 1.43)),
 'spine.006':   ((0, 0.0, 1.43),  (0, 0.0, 1.62)),
 'shoulder.L':  ((0.03, 0.0, 1.285),  (0.19, 0.0, 1.30)),
 'upper_arm.L': ((0.21, 0.0, 1.30),   (0.299, 0.03, 1.056)),
 'forearm.L':   ((0.299, 0.03, 1.056), (0.388, 0.0, 0.812)),
 'hand.L':      ((0.388, 0.0, 0.812), (0.426, 0.0, 0.70)),
 'thigh.L':     ((0.105, 0.0, 0.76),  (0.105, -0.02, 0.44)),
 'shin.L':      ((0.105, -0.02, 0.44), (0.105, 0.01, 0.10)),
 'foot.L':      ((0.105, 0.01, 0.10), (0.105, -0.105, 0.03)),
 'toe.L':       ((0.105, -0.105, 0.03), (0.105, -0.20, 0.03)),
 'heel.02.L':   ((0.065, 0.075, 0.0), (0.145, 0.075, 0.0)),
}

meta = bpy.context.view_layer.objects.active
if meta is None or meta.type != 'ARMATURE':
    meta = bpy.data.objects.get('metarig')
assert meta is not None and meta.type == 'ARMATURE', 'Add the Basic Human metarig first'
meta.name = 'char_farmer_metarig'
meta.data.name = 'char_farmer_metarig'
bpy.context.view_layer.objects.active = meta
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.mode_set(mode='EDIT')
eb = meta.data.edit_bones
for n in ('pelvis.L', 'pelvis.R', 'breast.L', 'breast.R'):
    if n in eb: eb.remove(eb[n])
for name, (h, t) in FIT.items():
    for nn in ([name] if not name.endswith('.L') else [name, name[:-1] + 'R']):
        sx = -1 if nn.endswith('.R') else 1
        e = eb[nn]
        e.head = (h[0] * sx, h[1], h[2])
        e.tail = (t[0] * sx, t[1], t[2])
bpy.ops.object.mode_set(mode='OBJECT')
for b in ('upper_arm.L', 'upper_arm.R', 'thigh.L', 'thigh.R'):
    meta.pose.bones[b].rigify_parameters.segments = 1
print('lm_fit_metarig: %d bones fitted' % len(meta.data.bones))
