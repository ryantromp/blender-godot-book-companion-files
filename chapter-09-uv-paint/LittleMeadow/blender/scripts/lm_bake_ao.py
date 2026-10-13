"""lm_bake_ao.py : Chapter 9.  Bakes ambient occlusion into vertex colours (Color Attribute 'AO') for the five buildings of
lm_structures.blend and gives them the material M_farm_ao (the atlas multiplied by AO).
Open lm_structures.blend (after lm_apply_cells.py), open this file in the Text Editor of the Scripting workspace, press Run Script."""
import bpy

DISTANCE = 1.5      # Render tab > Light Paths > Fast GI Approximation > AO Distance, in metres: how far a surface looks for blockers
SAMPLES = 64        # Cycles samples per bake
STRENGTH = 0.6      # the darkest corner ends at 1 - 0.6 = 0.4 (40 percent grey)
BUILDINGS = ['bld_farmhouse', 'bld_barn', 'bld_shed', 'bld_chicken_coop', 'bld_well']

def get_ao_material():
    """M_farm_ao = M_farm with the Color Attribute 'AO' multiplied into Base Color (needs bake_ao on every object that
    uses it: a missing attribute renders black in Blender). Travels in glTF as COLOR_0."""
    m = bpy.data.materials['M_farm']
    ao = bpy.data.materials.get('M_farm_ao') or m.copy()
    ao.name = 'M_farm_ao'
    ao.use_backface_culling = False     # like M_farm: glTF doubleSided true
    nt = ao.node_tree
    tex = nt.nodes['Atlas']
    bsdf = [n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    for l in list(nt.links):
        if l.to_node == bsdf and l.to_socket.name == 'Base Color':
            nt.links.remove(l)
    va = nt.nodes.get('AO') or nt.nodes.new('ShaderNodeVertexColor')
    va.name = 'AO'; va.label = 'AO'; va.layer_name = 'AO'; va.location = (-300, -400)
    mix = nt.nodes.get('Multiply') or nt.nodes.new('ShaderNodeMix')
    mix.name = 'Multiply'; mix.label = 'Multiply'; mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0; mix.location = (-60, 0)
    nt.links.new(tex.outputs['Color'], mix.inputs['A'])
    nt.links.new(va.outputs['Color'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
    return ao


def bake_ao(obj, distance=1.0, samples=64, strength=0.6, ground=True, attr='AO', engine_restore=True):
    """Cycles AO bake of obj into the Color Attribute `attr` (per face corner), then compress so the darkest corner is
    1 - strength (0.6 -> never darker than 40 % grey).  A temporary ground plane at z = 0 gives contact shadows.
    Returns (min, mean) of the baked values."""
    import numpy as np
    sc = bpy.context.scene
    old_engine = sc.render.engine
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = samples
    w = sc.world or bpy.data.worlds.new('World'); sc.world = w
    w.light_settings.distance = distance
    me = obj.data
    a = me.color_attributes.get(attr)
    if a is not None:
        me.color_attributes.remove(a)
    a = me.color_attributes.new(attr, 'BYTE_COLOR', 'CORNER')
    me.color_attributes.active_color = a
    gp = None
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=60, location=(obj.location.x, obj.location.y, 0))
        gp = bpy.context.object; gp.name = '_lm_tmp_ground'
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    bpy.ops.object.bake(type='AO', target='VERTEX_COLORS')
    n = len(me.attributes[attr].data)
    buf = np.zeros(n * 4, dtype=np.float32)
    me.attributes[attr].data.foreach_get('color', buf)
    v = buf.reshape(-1, 4)
    v[:, :3] = 1.0 - strength * (1.0 - v[:, :3])
    v[:, 3] = 1.0
    me.attributes[attr].data.foreach_set('color', v.ravel())
    if gp is not None:
        bpy.data.objects.remove(gp, do_unlink=True)
    if engine_restore:
        sc.render.engine = old_engine
    return float(v[:, 0].min()), float(v[:, 0].mean())


def run():
    ao = get_ao_material()
    done = set()
    for n in BUILDINGS:
        o = bpy.data.objects.get(n)
        if o is None or o.data.name in done:
            continue
        done.add(o.data.name)
        mn, mean = bake_ao(o, distance=DISTANCE, samples=SAMPLES, strength=STRENGTH)
        o.data.materials.clear()
        o.data.materials.append(ao)
        for p in o.data.polygons:
            p.material_index = 0
        print(n, 'AO baked: darkest', round(mn, 3), 'mean', round(mean, 3))


run()
