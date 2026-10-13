"""lm_animate.py : Chapter 17.  Builds the Actions of the farm.  Open lm_farmer.blend, lm_animals.blend or lm_machinery.blend,
open this file in the Text Editor of the Scripting workspace and press Run Script: it creates the Actions that belong to the
objects of the open file.
 lm_farmer.blend     char_farmer_idle-loop (skipped when you already made it by hand), _walk-loop, _run-loop, _plant, _water, _harvest
 lm_animals.blend    an_chicken_idle/walk/peck-loop, an_dog_idle-loop/walk-loop/bark, an_cow_idle/walk/graze-loop
 lm_machinery.blend  mach_windmill_spin-loop, mach_pump_pump, mach_tractor_drive-loop
A pose table is {frame: {bone: {'loc': (x, y, z), 'rot': (x, y, z)}}}: rotations in degrees, bone local axes, XYZ Euler, values
relative to the rest pose.  Each frame of a table becomes the same keyframes you insert with the I key.  Walk and run tables
list the first half cycle; the second half is the Copy Pose / Paste Flipped mirror of it, as in the chapter.
Every Action is pushed down to its own single-strip NLA track and the active Action slot is cleared, which is the state the
glTF exporter wants (one named animation per Action).  The NLA switch of a rig with several clips is turned off (the tick
beside the rig name in the NLA editor), so the rig rests in its A-pose instead of showing all clips stacked.  A name ending in -loop makes Godot loop the clip (and removes the suffix)."""
import bpy, math

def flip_name(n):
    if n.endswith('.L'): return n[:-2] + '.R'
    if n.endswith('.R'): return n[:-2] + '.L'
    return n

def flip_pose(pose):
    """Copy Pose, Paste Flipped: swap .L and .R bones, negate location X and rotation Y, Z."""
    out = {}
    for b, v in pose.items():
        nv = {}
        if 'loc' in v: nv['loc'] = (-v['loc'][0], v['loc'][1], v['loc'][2])
        if 'rot' in v: nv['rot'] = (v['rot'][0], -v['rot'][1], -v['rot'][2])
        out[flip_name(b)] = nv
    return out

def half_cycle(poses, half):
    """poses: {frame: pose} for the first half cycle (frames f .. f+half-1). Returns the full cycle incl. closing key."""
    f0 = min(poses)
    full = dict(poses)
    for f, p in poses.items():
        full[f + half] = flip_pose(p)
    full[f0 + 2 * half] = dict(poses[f0])
    return full

def bones_used(poses):
    s = {}
    for p in poses.values():
        for b, v in p.items():
            s.setdefault(b, set()).update(v.keys())
    return s

def make_action(rig, name, poses, loop=False, cyclic_range=True, linear=(), fps=24):
    """Create action `name` on `rig` from {frame: {bone: {'loc':(x,y,z),'rot':(x,y,z deg)}}}. Returns the action."""
    used = bones_used(poses)
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for b, props in used.items():
        pb = rig.pose.bones[b]
        if 'rot' in props: pb.rotation_mode = 'XYZ'
    for fr in sorted(poses):
        for b, props in used.items():
            pb = rig.pose.bones[b]
            v = poses[fr].get(b, {})
            if 'loc' in props:
                pb.location = v.get('loc', (0, 0, 0)); pb.keyframe_insert('location', frame=fr, group=b)
            if 'rot' in props:
                pb.rotation_euler = [math.radians(a) for a in v.get('rot', (0, 0, 0))]; pb.keyframe_insert('rotation_euler', frame=fr, group=b)
    # interpolation overrides
    slot = rig.animation_data.action_slot
    cb = act.layers[0].strips[0].channelbag(slot)
    for fc in cb.fcurves:
        for pat in linear:
            if pat in fc.data_path:
                for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'
    f0, f1 = min(poses), max(poses)
    act.use_frame_range = True; act.frame_start = f0; act.frame_end = f1
    act.use_cyclic = bool(loop)
    return act

def reset_pose(rig):
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)


def P(**kw): return kw
def foot(y, z=0.0, rx=0.0): return dict(loc=(0, y, z), rot=(rx, 0, 0))
def bone(loc=None, rot=None):
    d = {}
    if loc is not None: d['loc'] = loc
    if rot is not None: d['rot'] = rot
    return d

# ------------------------------------------------------------------ idle: 48 frames (2 s), by hand in the book
IDLE = {
 1:  {'torso': bone(loc=(0, 0, 0)), 'chest': bone(rot=(0, 0, 0)), 'head': bone(rot=(0, 0, 0)),
      'upper_arm_fk.L': bone(rot=(0, 0, 0)), 'upper_arm_fk.R': bone(rot=(0, 0, 0))},
 25: {'torso': bone(loc=(0, 0, 0.01)), 'chest': bone(rot=(-3, 0, 0)), 'head': bone(rot=(4, 0, 0)),
      'upper_arm_fk.L': bone(rot=(3, 0, 0)), 'upper_arm_fk.R': bone(rot=(3, 0, 0))},
}
IDLE[49] = dict(IDLE[1])

# ------------------------------------------------------------------ walk: 24 frames, half cycle 12
WALK_HALF = {
 1: {'torso': bone(loc=(0, 0, -0.08)), 'hips': bone(rot=(0, 0, -5)), 'chest': bone(rot=(0, 0, 8)),
     'foot_ik.L': foot(-0.25, 0, -12), 'foot_ik.R': foot(0.25, 0.08, 30),
     'upper_arm_fk.L': bone(rot=(-22, 0, 0)), 'upper_arm_fk.R': bone(rot=(22, 0, 0)),
     'forearm_fk.L': bone(rot=(5, 0, 0)), 'forearm_fk.R': bone(rot=(15, 0, 0))},
 4: {'torso': bone(loc=(0.01, 0, -0.09)), 'hips': bone(rot=(0, 0, -2.5)), 'chest': bone(rot=(0, 0, 4)),
     'foot_ik.L': foot(-0.125, 0, 0), 'foot_ik.R': foot(0.12, 0.10, 20),
     'upper_arm_fk.L': bone(rot=(-11, 0, 0)), 'upper_arm_fk.R': bone(rot=(11, 0, 0)),
     'forearm_fk.L': bone(rot=(5, 0, 0)), 'forearm_fk.R': bone(rot=(10, 0, 0))},
 7: {'torso': bone(loc=(0.02, 0, -0.04)), 'hips': bone(rot=(0, 0, 0)), 'chest': bone(rot=(0, 0, 0)),
     'foot_ik.L': foot(0.0, 0, 0), 'foot_ik.R': foot(-0.02, 0.12, 5),
     'upper_arm_fk.L': bone(rot=(0, 0, 0)), 'upper_arm_fk.R': bone(rot=(0, 0, 0)),
     'forearm_fk.L': bone(rot=(8, 0, 0)), 'forearm_fk.R': bone(rot=(8, 0, 0))},
 10: {'torso': bone(loc=(0.01, 0, -0.05)), 'hips': bone(rot=(0, 0, 2.5)), 'chest': bone(rot=(0, 0, -4)),
     'foot_ik.L': foot(0.125, 0, 0), 'foot_ik.R': foot(-0.18, 0.07, -10),
     'upper_arm_fk.L': bone(rot=(11, 0, 0)), 'upper_arm_fk.R': bone(rot=(-11, 0, 0)),
     'forearm_fk.L': bone(rot=(10, 0, 0)), 'forearm_fk.R': bone(rot=(5, 0, 0))},
}
WALK = half_cycle(WALK_HALF, 12)

# ------------------------------------------------------------------ run: 16 frames, half cycle 8
RUN_HALF = {
 1: {'torso': bone(loc=(0, 0, -0.10)), 'hips': bone(rot=(0, 0, -7)), 'chest': bone(rot=(10, 0, 10)), 'head': bone(rot=(-8, 0, 0)),
     'foot_ik.L': foot(-0.22, 0, -10), 'foot_ik.R': foot(-0.02, 0.22, 10),
     'upper_arm_fk.L': bone(rot=(-35, 0, 0)), 'upper_arm_fk.R': bone(rot=(35, 0, 0)),
     'forearm_fk.L': bone(rot=(70, 0, 0)), 'forearm_fk.R': bone(rot=(80, 0, 0))},
 3: {'torso': bone(loc=(0, 0, -0.12)), 'hips': bone(rot=(0, 0, -3)), 'chest': bone(rot=(10, 0, 4)), 'head': bone(rot=(-8, 0, 0)),
     'foot_ik.L': foot(0.0, 0, 0), 'foot_ik.R': foot(-0.14, 0.15, 5),
     'upper_arm_fk.L': bone(rot=(-15, 0, 0)), 'upper_arm_fk.R': bone(rot=(15, 0, 0)),
     'forearm_fk.L': bone(rot=(80, 0, 0)), 'forearm_fk.R': bone(rot=(80, 0, 0))},
 5: {'torso': bone(loc=(0, 0, -0.08)), 'hips': bone(rot=(0, 0, 3)), 'chest': bone(rot=(10, 0, -4)), 'head': bone(rot=(-8, 0, 0)),
     'foot_ik.L': foot(0.22, 0.0, 35), 'foot_ik.R': foot(-0.24, 0.08, 0),
     'upper_arm_fk.L': bone(rot=(20, 0, 0)), 'upper_arm_fk.R': bone(rot=(-20, 0, 0)),
     'forearm_fk.L': bone(rot=(85, 0, 0)), 'forearm_fk.R': bone(rot=(75, 0, 0))},
 7: {'torso': bone(loc=(0, 0, 0.0)), 'hips': bone(rot=(0, 0, 6)), 'chest': bone(rot=(10, 0, -9)), 'head': bone(rot=(-8, 0, 0)),
     'foot_ik.L': foot(0.12, 0.24, 15), 'foot_ik.R': foot(-0.24, 0.04, -10),
     'upper_arm_fk.L': bone(rot=(35, 0, 0)), 'upper_arm_fk.R': bone(rot=(-35, 0, 0)),
     'forearm_fk.L': bone(rot=(85, 0, 0)), 'forearm_fk.R': bone(rot=(70, 0, 0))},
}
RUN = half_cycle(RUN_HALF, 8)

# ------------------------------------------------------------------ one-shot work cycles (right hand holds the tool)
PLANT = {
 1:  {},
 8:  {'torso': bone(loc=(0, 0, -0.20)), 'chest': bone(rot=(25, 0, 0)), 'head': bone(rot=(-10, 0, 0)),
      'upper_arm_fk.R': bone(rot=(45, 0, 0)), 'forearm_fk.R': bone(rot=(20, 0, 0)), 'upper_arm_fk.L': bone(rot=(15, 0, 0))},
 16: {'torso': bone(loc=(0, 0, -0.32)), 'chest': bone(rot=(40, 0, 0)), 'head': bone(rot=(-20, 0, 0)),
      'upper_arm_fk.R': bone(rot=(75, 0, 0)), 'forearm_fk.R': bone(rot=(20, 0, 0)), 'upper_arm_fk.L': bone(rot=(25, 0, 0))},
 20: {'torso': bone(loc=(0, 0, -0.32)), 'chest': bone(rot=(40, 0, 0)), 'head': bone(rot=(-20, 0, 0)),
      'upper_arm_fk.R': bone(rot=(75, 0, 0)), 'forearm_fk.R': bone(rot=(5, 0, 0)), 'upper_arm_fk.L': bone(rot=(25, 0, 0))},
 24: {'torso': bone(loc=(0, 0, -0.32)), 'chest': bone(rot=(40, 0, 0)), 'head': bone(rot=(-20, 0, 0)),
      'upper_arm_fk.R': bone(rot=(75, 0, 0)), 'forearm_fk.R': bone(rot=(20, 0, 0)), 'upper_arm_fk.L': bone(rot=(25, 0, 0))},
 32: {'torso': bone(loc=(0, 0, -0.10)), 'chest': bone(rot=(12, 0, 0)), 'head': bone(rot=(-5, 0, 0)),
      'upper_arm_fk.R': bone(rot=(25, 0, 0)), 'forearm_fk.R': bone(rot=(10, 0, 0)), 'upper_arm_fk.L': bone(rot=(8, 0, 0))},
 40: {},
}
WATER = {
 1:  {},
 10: {'chest': bone(rot=(6, 0, 0)), 'head': bone(rot=(8, 0, 0)),
      'upper_arm_fk.R': bone(rot=(65, 0, 0)), 'forearm_fk.R': bone(rot=(45, 0, 0)), 'hand_fk.R': bone(rot=(0, 0, 0))},
 18: {'chest': bone(rot=(6, 0, 0)), 'head': bone(rot=(10, 0, 0)),
      'upper_arm_fk.R': bone(rot=(65, 0, 0)), 'forearm_fk.R': bone(rot=(45, 0, 0)), 'hand_fk.R': bone(rot=(0, 0, 50))},
 34: {'chest': bone(rot=(6, 0, 0)), 'head': bone(rot=(10, 0, 0)),
      'upper_arm_fk.R': bone(rot=(65, 0, 0)), 'forearm_fk.R': bone(rot=(45, 0, 0)), 'hand_fk.R': bone(rot=(0, 0, 50))},
 42: {'chest': bone(rot=(6, 0, 0)), 'head': bone(rot=(8, 0, 0)),
      'upper_arm_fk.R': bone(rot=(65, 0, 0)), 'forearm_fk.R': bone(rot=(45, 0, 0)), 'hand_fk.R': bone(rot=(0, 0, 0))},
 52: {},
}
HARVEST = {
 1:  {},
 8:  {'torso': bone(loc=(0, 0, -0.25)), 'chest': bone(rot=(35, 0, 0)), 'head': bone(rot=(-15, 0, 0)),
      'upper_arm_fk.L': bone(rot=(55, 0, 0)), 'upper_arm_fk.R': bone(rot=(55, 0, 0)), 'forearm_fk.L': bone(rot=(15, 0, 0)), 'forearm_fk.R': bone(rot=(15, 0, 0))},
 14: {'torso': bone(loc=(0, 0, -0.25)), 'chest': bone(rot=(35, 0, 0)), 'head': bone(rot=(-15, 0, 0)),
      'upper_arm_fk.L': bone(rot=(55, 0, 0)), 'upper_arm_fk.R': bone(rot=(55, 0, 0)), 'forearm_fk.L': bone(rot=(30, 0, 0)), 'forearm_fk.R': bone(rot=(30, 0, 0))},
 24: {'torso': bone(loc=(0, 0, -0.04)), 'chest': bone(rot=(-8, 0, 0)), 'head': bone(rot=(5, 0, 0)),
      'upper_arm_fk.L': bone(rot=(50, 0, 0)), 'upper_arm_fk.R': bone(rot=(50, 0, 0)), 'forearm_fk.L': bone(rot=(75, 0, 0)), 'forearm_fk.R': bone(rot=(75, 0, 0))},
 32: {'torso': bone(loc=(0, 0, 0)), 'chest': bone(rot=(0, 0, 0)), 'head': bone(rot=(0, 0, 0)),
      'upper_arm_fk.L': bone(rot=(10, 0, 0)), 'upper_arm_fk.R': bone(rot=(10, 0, 0)), 'forearm_fk.L': bone(rot=(20, 0, 0)), 'forearm_fk.R': bone(rot=(20, 0, 0))},
 40: {},
}
FARMER_ACTIONS = [  # name, poses, loop, linear patterns
 ('char_farmer_idle', IDLE, True, ()),
 ('char_farmer_walk', WALK, True, ('foot_ik.L"].location', 'foot_ik.R"].location')),
 ('char_farmer_run', RUN, True, ('foot_ik.L"].location', 'foot_ik.R"].location')),
 ('char_farmer_plant', PLANT, False, ()),
 ('char_farmer_water', WATER, False, ()),
 ('char_farmer_harvest', HARVEST, False, ()),
]

def b(rot=None, loc=None):
    d = {}
    if rot is not None: d['rot'] = rot
    if loc is not None: d['loc'] = loc
    return d
def X(a): return (a, 0, 0)
def Z(a): return (0, 0, a)
def Y(a): return (0, a, 0)

# ------------------------------------------------------------------ chicken
CH_IDLE = {
 1:  {},
 13: {'neck': b(X(6)), 'head': b(X(-5)), 'tail': b(X(4)), 'spine': b(X(-1))},
 25: {'neck': b(X(-3)), 'head': b(X(3)), 'wing.L': b(Y(8)), 'wing.R': b(Y(-8))},
 37: {'neck': b(X(6)), 'head': b(X(-5)), 'tail': b(X(4)), 'spine': b(X(-1))},
 49: {},
}
CH_WALK_HALF = {
 1: {'root': b(loc=(0, 0, 0.0)), 'leg.L': b(X(-30)), 'leg.R': b(X(30), (0, 0, 0.03)), 'foot.L': b(X(5)), 'foot.R': b(X(35)), 'neck': b(X(12)), 'head': b(X(-12)), 'spine': b(X(0))},
 4: {'root': b(loc=(0, 0, -0.006)), 'leg.L': b(X(-15)), 'leg.R': b(X(10), (0, 0, 0.04)), 'foot.L': b(X(0)), 'foot.R': b(X(20)), 'neck': b(X(4)), 'head': b(X(-4)), 'spine': b(X(-2))},
 7: {'root': b(loc=(0, 0, 0.0)), 'leg.L': b(X(0)), 'leg.R': b(X(-15), (0, 0, 0.03)), 'foot.L': b(X(0)), 'foot.R': b(X(0)), 'neck': b(X(-6)), 'head': b(X(6)), 'spine': b(X(0))},
 10: {'root': b(loc=(0, 0, 0.004)), 'leg.L': b(X(15)), 'leg.R': b(X(-28), (0, 0, 0.01)), 'foot.L': b(X(0)), 'foot.R': b(X(-10)), 'neck': b(X(4)), 'head': b(X(-4)), 'spine': b(X(2))},
}
CH_WALK = half_cycle(CH_WALK_HALF, 12)
CH_PECK = {
 1:  {},
 4:  {'spine': b(X(-4)), 'neck': b(X(-12)), 'head': b(X(-10))},
 7:  {'spine': b(X(24)), 'neck': b(X(35)), 'head': b(X(30)), 'tail': b(X(-15))},
 10: {'spine': b(X(0)), 'neck': b(X(-6)), 'head': b(X(-6))},
 13: {'spine': b(X(24)), 'neck': b(X(35)), 'head': b(X(30)), 'tail': b(X(-15))},
 17: {'spine': b(X(0)), 'neck': b(X(-4)), 'head': b(X(-4))},
 25: {},
}
# ------------------------------------------------------------------ dog
DG_IDLE = {
 1:  {},
 13: {'spine': b(X(-1.5)), 'head': b(Y(12)), 'tail': b(Z(15)), 'tail.001': b(Z(15)), 'ear.L': b(Z(0))},
 25: {'head': b(X(3)), 'tail': b(Z(0))},
 37: {'spine': b(X(-1.5)), 'head': b(Y(-12)), 'tail': b(Z(-15)), 'tail.001': b(Z(-15))},
 49: {},
}
def dgl(fu, fl, hu, hl, pf=0, ph=0):
    return {'F_up': fu, 'F_lo': fl, 'H_up': hu, 'H_lo': hl}
def dog_pose(fL, fR, hL, hR, extra=None):
    """fL = (upper, lower) rot X for the left front leg, etc."""
    p = {'leg_f_upper.L': b(X(fL[0])), 'leg_f_lower.L': b(X(fL[1])), 'leg_f_upper.R': b(X(fR[0])), 'leg_f_lower.R': b(X(fR[1])),
         'leg_h_upper.L': b(X(hL[0])), 'leg_h_lower.L': b(X(hL[1])), 'leg_h_upper.R': b(X(hR[0])), 'leg_h_lower.R': b(X(hR[1]))}
    p.update(extra or {})
    return p
DG_WALK_HALF = {   # diagonal pairs: left front with right hind
 1: dog_pose((-28, 0), (25, 25), (25, 25), (-28, 0), {'root': b(loc=(0, 0, -0.01)), 'spine': b(Y(3)), 'head': b(X(3)), 'tail': b(Z(8))}),
 4: dog_pose((-14, 0), (10, 55), (12, 45), (-14, 0), {'root': b(loc=(0, 0, -0.015)), 'spine': b(Y(1)), 'head': b(X(0)), 'tail': b(Z(4))}),
 7: dog_pose((0, 0), (-10, 45), (-8, 45), (0, 0), {'root': b(loc=(0, 0, 0.0)), 'spine': b(Y(0)), 'head': b(X(-3)), 'tail': b(Z(0))}),
 10: dog_pose((14, 0), (-25, 15), (-22, 15), (14, 0), {'root': b(loc=(0, 0, 0.005)), 'spine': b(Y(-1)), 'head': b(X(0)), 'tail': b(Z(-4))}),
}
DG_WALK = half_cycle(DG_WALK_HALF, 12)
DG_BARK = {
 1:  {},
 4:  {'spine': b(X(4)), 'head': b(X(8)), 'neck': b(X(6)), 'leg_f_upper.L': b(X(6)), 'leg_f_upper.R': b(X(6))},
 8:  {'spine': b(X(-6)), 'head': b(X(-30)), 'neck': b(X(-18)), 'tail': b(X(-10)), 'leg_f_upper.L': b(X(-4)), 'leg_f_upper.R': b(X(-4))},
 10: {'spine': b(X(-2)), 'head': b(X(-10)), 'neck': b(X(-6)), 'tail': b(X(-6))},
 13: {'spine': b(X(-6)), 'head': b(X(-30)), 'neck': b(X(-18)), 'tail': b(X(-10)), 'leg_f_upper.L': b(X(-4)), 'leg_f_upper.R': b(X(-4))},
 16: {'spine': b(X(-2)), 'head': b(X(-8)), 'neck': b(X(-4))},
 24: {},
}
# ------------------------------------------------------------------ cow
CW_IDLE = {
 1:  {},
 13: {'spine': b(X(-0.8)), 'chest': b(X(-0.8)), 'head': b(X(3)), 'tail': b(Z(18)), 'tail.001': b(Z(12))},
 25: {'ear.L': b(Z(12)), 'head': b(X(2))},
 37: {'spine': b(X(-0.8)), 'chest': b(X(-0.8)), 'head': b(X(3)), 'tail': b(Z(-18)), 'tail.001': b(Z(-12))},
 49: {},
}
def cow_pose(fL, fR, hL, hR, extra=None):
    p = {'leg_f_upper.L': b(X(fL[0])), 'leg_f_lower.L': b(X(fL[1])), 'leg_f_upper.R': b(X(fR[0])), 'leg_f_lower.R': b(X(fR[1])),
         'leg_h_upper.L': b(X(hL[0])), 'leg_h_lower.L': b(X(hL[1])), 'leg_h_upper.R': b(X(hR[0])), 'leg_h_lower.R': b(X(hR[1]))}
    p.update(extra or {}); return p
CW_WALK_HALF = {   # 32 frames, half 16, keys every 4
 1:  cow_pose((-20, 0), (18, 25), (18, 25), (-20, 0), {'root': b(loc=(0, 0, -0.01)), 'spine': b(Y(1.5)), 'neck': b(X(3)), 'head': b(X(2)), 'tail': b(Z(8))}),
 5:  cow_pose((-10, 0), (8, 45), (8, 40), (-10, 0), {'root': b(loc=(0, 0, -0.015)), 'spine': b(Y(0.5)), 'neck': b(X(1)), 'head': b(X(0)), 'tail': b(Z(4))}),
 9:  cow_pose((0, 0), (-8, 40), (-6, 35), (0, 0), {'root': b(loc=(0, 0, 0)), 'spine': b(Y(0)), 'neck': b(X(-1)), 'head': b(X(-2)), 'tail': b(Z(0))}),
 13: cow_pose((10, 0), (-18, 15), (-16, 12), (10, 0), {'root': b(loc=(0, 0, 0.005)), 'spine': b(Y(-0.5)), 'neck': b(X(1)), 'head': b(X(0)), 'tail': b(Z(-4))}),
}
CW_WALK = half_cycle(CW_WALK_HALF, 16)
CW_GRAZE = {
 1:  {'neck': b(X(55)), 'head': b(X(45)), 'chest': b(X(2))},
 17: {'neck': b(X(50)), 'head': b(X(40)), 'chest': b(X(2)), 'tail': b(Z(25)), 'ear.L': b(Z(15))},
 33: {'neck': b(X(55)), 'head': b(X(47)), 'chest': b(X(2))},
 49: {'neck': b(X(50)), 'head': b(X(40)), 'chest': b(X(2)), 'tail': b(Z(-25)), 'ear.R': b(Z(-15))},
}
CW_GRAZE[65] = dict(CW_GRAZE[1])
ANIMAL_ACTIONS = {
 'an_chicken': [('an_chicken_idle', CH_IDLE, True, ()), ('an_chicken_walk', CH_WALK, True, ()), ('an_chicken_peck', CH_PECK, True, ())],
 'an_dog': [('an_dog_idle', DG_IDLE, True, ()), ('an_dog_walk', DG_WALK, True, ()), ('an_dog_bark', DG_BARK, False, ())],
 'an_cow': [('an_cow_idle', CW_IDLE, True, ()), ('an_cow_walk', CW_WALK, True, ()), ('an_cow_graze', CW_GRAZE, True, ())],
}

def key_rot(obj, act, slot, axis, frames_deg, interp='LINEAR'):
    obj.animation_data_create()
    obj.animation_data.action = act
    obj.animation_data.action_slot = slot
    obj.rotation_mode = 'XYZ'
    for fr, deg in frames_deg:
        e = list(obj.rotation_euler); e[axis] = math.radians(deg); obj.rotation_euler = e
        obj.keyframe_insert('rotation_euler', index=axis, frame=fr)
    obj.rotation_euler = (0, 0, 0)

def fcurves_of(act, slot):
    return act.layers[0].strips[0].channelbag(slot).fcurves

def make_machine_actions():
    D = bpy.data.objects
    out = {}
    # windmill: one full turn of the blades in 96 frames, clockwise seen from the front (positive Y)
    a = bpy.data.actions.new('mach_windmill_spin-loop'); s = a.slots.new('OBJECT', 'blades')
    key_rot(D['mach_windmill__blades'], a, s, 1, [(1, 0), (97, 360)])
    for fc in fcurves_of(a, s):
        for k in fc.keyframe_points: k.interpolation = 'LINEAR'
        m = fc.modifiers.new('CYCLES'); m.mode_before = 'REPEAT_OFFSET'; m.mode_after = 'REPEAT_OFFSET'
    a.use_frame_range = True; a.frame_start = 1; a.frame_end = 97; a.use_cyclic = True
    D['mach_windmill__blades'].animation_data.action = None
    out['windmill'] = a
    # pump: one stroke of the lever in 24 frames (the handle is the +Y end, so positive X lifts it: up 25, down -12, back to 0)
    a = bpy.data.actions.new('mach_pump_pump'); s = a.slots.new('OBJECT', 'lever')
    key_rot(D['mach_pump__lever'], a, s, 0, [(1, 0), (9, 25), (17, -12), (25, 0)], interp='BEZIER')
    a.use_frame_range = True; a.frame_start = 1; a.frame_end = 25
    D['mach_pump__lever'].animation_data.action = None
    out['pump'] = a
    # tractor: one action, two slots (rear and front wheels), 48 frames
    a = bpy.data.actions.new('mach_tractor_drive-loop')
    rear = a.slots.new('OBJECT', 'rear'); front = a.slots.new('OBJECT', 'front')
    # rear wheel R 0.65: 1 turn; front wheel R 0.4: 1.625 turns would not loop: use 2 turns (front) vs 1 (rear)
    for names, slot, deg in ((('mach_tractor__wheel_rl', 'mach_tractor__wheel_rr'), rear, 360), (('mach_tractor__wheel_fl', 'mach_tractor__wheel_fr'), front, 720)):
        for n in names:
            key_rot(D[n], a, slot, 0, [(1, 0), (49, deg)])
    for slot in (rear, front):
        for fc in fcurves_of(a, slot):
            for k in fc.keyframe_points: k.interpolation = 'LINEAR'
    a.use_frame_range = True; a.frame_start = 1; a.frame_end = 49; a.use_cyclic = True
    for n in ('mach_tractor__wheel_rl', 'mach_tractor__wheel_rr', 'mach_tractor__wheel_fl', 'mach_tractor__wheel_fr'):
        D[n].animation_data.action = None
    out['tractor'] = a
    return out

def push_down(ad, act, slot=None):
    """what the Push Down button does: the Action becomes one strip on a new NLA track, nothing stays active"""
    tr = ad.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act)
    if slot is not None: st.action_slot = slot
    ad.action = None
    return st

def build_rig_actions(rig, table):
    ad = rig.animation_data_create()
    for name, poses, loop, linear in table:
        full = name + '-loop' if loop else name
        if full in bpy.data.actions or name in bpy.data.actions: continue
        reset_pose(rig)
        act = make_action(rig, full, poses, loop=loop, linear=linear)
        push_down(ad, act)
    reset_pose(rig)
    ad.use_nla = False      # the clips are stored, not played stacked: the rig stays in its rest pose (export ignores this switch)

def stash(obj, act, slot_name):
    """put the Action (one slot per animated object) on a single-strip NLA track of obj"""
    ad = obj.animation_data_create()
    slot = [s for s in act.slots if s.name_display == slot_name][0]
    ad.action = act; ad.action_slot = slot
    tr = ad.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.action_slot = slot
    ad.action = None

def build_machine_actions():
    if 'mach_windmill_spin-loop' in bpy.data.actions: return
    D = bpy.data.objects
    acts = make_machine_actions()
    stash(D['mach_windmill__blades'], acts['windmill'], 'blades')
    stash(D['mach_pump__lever'], acts['pump'], 'lever')
    for n, sn in (('mach_tractor__wheel_rl', 'rear'), ('mach_tractor__wheel_rr', 'rear'),
                  ('mach_tractor__wheel_fl', 'front'), ('mach_tractor__wheel_fr', 'front')):
        stash(D[n], acts['tractor'], sn)

if 'char_farmer_rig' in bpy.data.objects:
    rig = bpy.data.objects['char_farmer_rig']
    build_rig_actions(rig, FARMER_ACTIONS)
for animal, table in ANIMAL_ACTIONS.items():
    if animal + '_rig' in bpy.data.objects:
        build_rig_actions(bpy.data.objects[animal + '_rig'], table)
if 'mach_windmill__blades' in bpy.data.objects:
    build_machine_actions()
print('lm_animate: %d actions' % len(bpy.data.actions))
