"""lm_vfx_sheets.py : Chapter 18.  Renders the three flipbook sheets into LittleMeadow/textures/.
Open lm_vfx.blend (saved in LittleMeadow/blender/), open this file in the Text Editor, press Run Script.
One render per sheet: 16 poses of an effect stand in a 4 x 4 grid of 1 m cells, an orthographic camera looks at the whole grid,
Cycles draws 2048 x 2048 px with a transparent background. Cell n (0 to 15) is column n % 4, row n // 4, read left to right, top to bottom."""
import math
import bpy
import bmesh

COLS = ROWS = 4
CELL_PX = 512
SAMPLES = 16
TEXTURES = bpy.path.abspath("//../textures/")


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1.0 - (1.0 - t) ** 2


def make_material(name, emission):
    """One shader for every blob: colour and alpha come from the object colour (Object Info node)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    info = nt.nodes.new('ShaderNodeObjectInfo')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    flip = nt.nodes.new('ShaderNodeMath')
    flip.operation = 'SUBTRACT'
    flip.inputs[0].default_value = 1.0
    times = nt.nodes.new('ShaderNodeMath')
    times.operation = 'MULTIPLY'
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(geo.outputs['Backfacing'], flip.inputs[1])
    nt.links.new(info.outputs['Alpha'], times.inputs[0])
    nt.links.new(flip.outputs[0], times.inputs[1])
    nt.links.new(info.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(times.outputs[0], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 1.0
    if emission:
        nt.links.new(info.outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = emission
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return mat


def make_blob_mesh():
    me = bpy.data.meshes.new("vfx_blob")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for f in bm.faces:
        f.smooth = False
    bm.to_mesh(me)
    bm.free()
    return me


def make_star_mesh():
    """A flat four-pointed star, 8 corners, 0.02 m thick."""
    me = bpy.data.meshes.new("vfx_star")
    bm = bmesh.new()
    pts = [bm.verts.new((math.sin(k * math.pi / 4) * (1.0 if k % 2 == 0 else 0.2),
                         0.0,
                         math.cos(k * math.pi / 4) * (1.0 if k % 2 == 0 else 0.2))) for k in range(8)]
    face = bm.faces.new(pts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    verts = [v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=verts, vec=(0.0, 0.02, 0.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return me


class Sheet:
    def __init__(self, name, material, mesh):
        self.scene = bpy.data.scenes.new(name)
        self.coll = bpy.data.collections.new(name + "_items")
        self.scene.collection.children.link(self.coll)
        self.mat, self.mesh = material, mesh

    def cell_centre(self, n):
        return float(n % COLS), -float(n // COLS)

    def blob(self, n, dx, dz, size, rgba, squash=1.0, spin=0.0, name="blob"):
        cx, cz = self.cell_centre(n)
        ob = bpy.data.objects.new("%s_%02d" % (name, n), self.mesh)
        ob.data.materials.clear()
        ob.data.materials.append(self.mat)
        ob.location = (cx + dx, 0.0, cz + dz)
        ob.scale = (size, size, size * squash)
        ob.rotation_euler = (0.0, spin, 0.0)
        ob.color = rgba
        ob.visible_shadow = False
        self.coll.objects.link(ob)
        return ob

    def finish(self, path, samples):
        sc = self.scene
        cam = bpy.data.objects.new("vfx_cam", bpy.data.cameras.new("vfx_cam"))
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = float(COLS)
        cam.location = ((COLS - 1) / 2.0, -10.0, -(ROWS - 1) / 2.0)
        cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        sc.collection.objects.link(cam)
        sc.camera = cam
        sun = bpy.data.objects.new("vfx_sun", bpy.data.lights.new("vfx_sun", 'SUN'))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(55.0), 0.0, math.radians(-30.0))
        sc.collection.objects.link(sun)
        sc.world = bpy.data.worlds.new(sc.name + "_world")
        sc.world.color = (0.6, 0.6, 0.6)
        r = sc.render
        r.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
        r.film_transparent = True
        r.resolution_x, r.resolution_y = COLS * CELL_PX, ROWS * CELL_PX
        r.resolution_percentage = 100
        r.image_settings.file_format = 'PNG'
        r.image_settings.color_mode = 'RGBA'
        r.image_settings.color_depth = '8'
        sc.view_settings.view_transform = 'Standard'
        r.filepath = path
        bpy.ops.render.render(write_still=True, scene=sc.name)
        print("wrote", path)
        bpy.data.scenes.remove(sc)


def dust_puff(sh):
    sand = (0.80, 0.70, 0.54)
    for n in range(16):
        t = n / 15.0
        e = ease_out(t)
        fade = (1.0 - t) ** 1.3 * 0.9
        for k, (ox, rise, r0) in enumerate([(-0.30, 0.05, 0.10), (-0.18, 0.12, 0.13), (-0.06, 0.19, 0.12),
                                             (0.06, 0.17, 0.14), (0.18, 0.11, 0.12), (0.30, 0.04, 0.10),
                                             (0.00, 0.06, 0.15)]):
            sh.blob(n, ox * (0.35 + 0.6 * e), -0.38 + rise * e * 1.4, r0 * (0.5 + 0.7 * e),
                    sand + (fade,), squash=0.85, spin=k * 0.7, name="puff")


def water_splash(sh):
    water = (0.55, 0.80, 0.95)
    foam = (0.90, 0.97, 1.00)
    for n in range(16):
        t = n / 15.0
        fade = 1.0 if t < 0.7 else (1.0 - t) / 0.3
        sh.blob(n, 0.0, -0.42, lerp(0.07, 0.40, ease_out(t)), foam + (0.55 * fade,), squash=0.12, name="ring")
        jet = math.sin(min(t / 0.5, 1.0) * math.pi) if t < 0.5 else 0.0
        if jet > 0.02:
            sh.blob(n, 0.0, -0.40 + 0.16 * jet, 0.06 + 0.02 * jet, water + (1.0,), squash=1.9, name="jet")
        for k, ang in enumerate([-58, -38, -20, -6, 8, 22, 40, 60]):
            a = math.radians(ang)
            tau = t * 1.25
            x = math.sin(a) * 0.42 * tau * (0.8 + 0.05 * (k % 3))
            z = -0.40 + math.cos(a) * 0.62 * tau - 0.50 * tau * tau
            if z < -0.44:
                continue
            sh.blob(n, x, z, 0.045 + 0.012 * (k % 3), water + (fade,), name="drop")


def sparkle(sh):
    gold = (1.0, 0.72, 0.15)
    for n in range(16):
        t = n / 15.0
        pulse = math.sin(t * math.pi) ** 0.9
        sh.blob(n, 0.0, 0.0, 0.40 * pulse, gold + (1.0,), spin=t * math.pi / 2, name="star")
        for k, (dx, dz, s) in enumerate([(-0.30, 0.26, 0.14), (0.31, 0.18, 0.11), (0.22, -0.30, 0.13)]):
            p = math.sin(min(max(t * 1.15 - 0.12 * k, 0.0), 1.0) * math.pi) ** 0.9
            sh.blob(n, dx, dz, s * p, gold + (1.0,), spin=-t * math.pi / 2, name="star_s")


EFFECTS = [("vfx_dust_puff", dust_puff, 0.0), ("vfx_water_splash", water_splash, 0.0), ("vfx_sparkle", sparkle, 1.0)]


def run(samples=SAMPLES, folder=TEXTURES):
    star, blob = make_star_mesh(), make_blob_mesh()
    for name, builder, emission in EFFECTS:
        sh = Sheet(name + "_sheet", make_material(name + "_mat", emission), star if name == "vfx_sparkle" else blob)
        builder(sh)
        sh.finish(folder + name + ".png", samples)


if __name__ == "__main__":
    run()
