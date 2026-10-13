"""lm_apply_cells.py : Chapter 9.  Runs the face-group table of Chapter 9 on lm_props.blend or lm_structures.blend.
Open the .blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
Part 1 is the helper library (UV islands into atlas cells), part 2 is the table (SPEC), part 3 runs it."""
import os, json, math
from collections import namedtuple
import bpy, bmesh
from mathutils import Vector

TEX = bpy.path.abspath('//../textures')   # next to the blender folder of the open .blend
# palette embedded below
PAL = {"world_atlas":{"size":1024,"cell":128,"cols":8,"cells":[["pal_grass_mid","#5E9E47"],["pal_grass_light","#7DBB5A"],["pal_grass_dark","#3F7A3A"],["pal_grass_hi","#A5D46A"],["pal_leaf_dark","#2F6B3B"],["pal_leaf_light","#86C45E"],["pal_pine","#2A5D4A"],["pal_hedge","#3B7D45"],["pal_soil_dark","#4A3426"],["pal_soil_mid","#6B4A32"],["pal_soil_dry","#A47A55"],["pal_soil_wet","#3A2A20"],["pal_path","#B89868"],["pal_stone_dark","#5A5D62"],["pal_stone_mid","#8C8F94"],["pal_stone_light","#B4B8BC"],["pal_wood_dark","#6A432A"],["pal_wood_mid","#8B5E3C"],["pal_wood_light","#A97C50"],["pal_wood_pale","#C9A06E"],["pal_straw_dark","#B08C3C"],["pal_straw_mid","#D9B45A"],["pal_straw_light","#EBCF7F"],["pal_bark","#5B4636"],["pal_roof_dark","#8E3329"],["pal_roof_mid","#B5483A"],["pal_roof_light","#D2634F"],["pal_plaster","#EFE6D2"],["pal_plaster_shade","#D8CCB3"],["pal_glass","#9CCBE0"],["pal_door_blue","#3F6FB0"],["pal_brick","#A4553F"],["pal_water_mid","#4C9FD1"],["pal_water_light","#7CC4E8"],["pal_water_dark","#2F76A8"],["pal_steel","#7A7F86"],["pal_iron_dark","#4B4F55"],["pal_brass","#C79A3B"],["pal_tractor_red","#C73E2F"],["pal_tractor_green","#3E8C4A"],["pal_carrot","#E8812B"],["pal_carrot_top","#4FA03E"],["pal_wheat_gold","#E3B33F"],["pal_pumpkin","#E07A1F"],["pal_flower_pink","#E87AA0"],["pal_flower_yellow","#F2D43D"],["pal_flower_purple","#8E6BC1"],["pal_flower_white","#F4F1EA"]],"tiles":[["detail_wood_planks",[0,768,256,256]],["detail_stone",[256,768,256,256]],["detail_roof_thatch",[512,768,256,256]],["detail_dirt_grass",[768,768,256,256]]]},"char_atlas":{"size":1024,"cell":128,"cols":8,"cells":[["pal_skin_light","#F2C9A5"],["pal_skin_mid","#C98F66"],["pal_skin_dark","#8D5A3B"],["pal_hair_brown","#4A3123"],["pal_hair_blonde","#D9B25A"],["pal_hair_black","#2A2220"],["pal_shirt_blue","#4A79B8"],["pal_shirt_red","#C0504A"],["pal_overalls","#5B6FA8"],["pal_denim_dark","#3E4F7C"],["pal_boots","#4A3326"],["pal_belt","#7A5230"],["pal_hat_straw","#D9B45A"],["pal_hat_band","#A83A32"],["pal_glove_tan","#C9A06E"],["pal_apron","#EFE6D2"],["pal_chicken_white","#F4EFE6"],["pal_chicken_shade","#D9D2C4"],["pal_comb","#D8422F"],["pal_beak","#E8A838"],["pal_cow_white","#F2F0EA"],["pal_cow_black","#2B2B2E"],["pal_cow_pink","#E8A5A5"],["pal_horn","#D8CDB0"],["pal_dog_tan","#C9955B"],["pal_dog_dark","#5E4128"],["pal_dog_belly","#EAD7B5"],["pal_nose","#2B2B2E"],["pal_eye","#1B1B1B"],["pal_tongue","#E57A87"],["pal_hoof","#4A3C30"],["pal_outline_dark","#3A2E2A"]],"tiles":[["detail_fur_noise",[0,512,256,256]],["detail_cloth",[256,512,256,256]]]}}
PALETTE = {}
for _k, _a in PAL.items():
    _cells = []
    for _i, (_n, _h) in enumerate(_a['cells']):
        _c, _r = _i % _a['cols'], _i // _a['cols']
        _cells.append(dict(index=_i, col=_c, row=_r, name=_n, hex=_h, px_rect=[_c * _a['cell'], _r * _a['cell'], _a['cell'], _a['cell']]))
    PALETTE[_k] = dict(size_px=_a['size'], cell_px=_a['cell'], cols=_a['cols'], cells=_cells,
                       detail_tiles=[dict(name=_n, px_rect=_r) for _n, _r in _a['tiles']])

PAD_PX = 4

_ATLAS = {
    'world': dict(key='world_atlas', material='M_farm', file='T_farm_atlas.png'),
    'char': dict(key='char_atlas', material='M_char', file='T_char_atlas.png'),
}
Cell = namedtuple('Cell', 'index col row name hex rect full is_detail')


def _a(atlas):
    return PALETTE[_ATLAS[atlas]['key']]


def atlas_path(atlas='world'):
    return os.path.join(TEX, _ATLAS[atlas]['file'])


def _mkcell(atlas, c, pad_px=PAD_PX):
    a = _a(atlas); S = a['size_px']
    x, y, w, h = c['px_rect']
    full = (x / S, 1 - (y + h) / S, (x + w) / S, 1 - y / S)
    rect = ((x + pad_px) / S, 1 - (y + h - pad_px) / S, (x + w - pad_px) / S, 1 - (y + pad_px) / S)
    return Cell(c.get('index', -1), c.get('col', -1), c.get('row', -1), c['name'], c.get('hex', ''), rect, full,
                'detail' in c['name'])


def atlas_cells(atlas='world'):
    return [_mkcell(atlas, c) for c in _a(atlas)['cells']]


def detail_tiles(atlas='world'):
    return [_mkcell(atlas, c) for c in _a(atlas).get('detail_tiles', [])]


def cell(ref, atlas='world', pad_px=PAD_PX):
    """Resolve an index / name / detail tile name to a Cell."""
    if isinstance(ref, Cell):
        return ref
    a = _a(atlas)
    for c in a['cells']:
        if isinstance(ref, int) and ref == c['index']:
            return _mkcell(atlas, c, pad_px)
        if isinstance(ref, str) and ref in (c['name'], c['name'].replace('pal_', '')):
            return _mkcell(atlas, c, pad_px)
    for c in a.get('detail_tiles', []):
        if isinstance(ref, str) and ref in (c['name'], c['name'].replace('detail_', '')):
            return _mkcell(atlas, c, pad_px)
    raise KeyError('unknown atlas cell: %r' % (ref,))


# ------------------------------------------------------------------ atlas image + material
def hex_rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def make_flat_atlas(atlas='world', path=None, detail=True, name=None):
    """Write the flat colour layout (one hex per cell; detail tiles in a base colour) as a PNG. Returns the path.
    (8 bit images store sRGB values in .pixels, so the hex values are written unchanged.)"""
    import numpy as np
    a = _a(atlas); S = a['size_px']
    px = np.ones((S, S, 4), dtype=np.float32)
    px[..., :3] = 0.5
    for c in a['cells']:
        x, y, w, h = c['px_rect']
        px[S - y - h:S - y, x:x + w, :3] = hex_rgb(c['hex'])
    base = {'detail_wood_planks': '#A97C50', 'detail_stone': '#8C8F94', 'detail_roof_thatch': '#D9B45A',
            'detail_dirt_grass': '#5E9E47'}
    if detail:
        for c in a.get('detail_tiles', []):
            x, y, w, h = c['px_rect']
            px[S - y - h:S - y, x:x + w, :3] = hex_rgb(base[c['name']])
    img = bpy.data.images.new(name or ('_flat_' + _ATLAS[atlas]['file']), S, S, alpha=False)
    img.pixels.foreach_set(px.ravel()); img.update()
    path = path or atlas_path(atlas)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.filepath_raw = path; img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)
    return path


def get_atlas_image(atlas='world'):
    """The atlas as a Blender image, file path relative to the .blend ('//../textures/...')."""
    fn = _ATLAS[atlas]['file']
    img = bpy.data.images.get(fn)
    if img is None:
        p = atlas_path(atlas)
        if not os.path.exists(p):
            print('lm_uv WARNING: %s missing, writing flat fallback' % p)
            make_flat_atlas(atlas, p)
        img = bpy.data.images.load(p, check_existing=True)
        img.name = fn
    img.colorspace_settings.name = 'sRGB'
    img.alpha_mode = 'NONE'
    if bpy.data.filepath:
        try:
            img.filepath = bpy.path.relpath(atlas_path(atlas)).replace('\\', '/')
        except Exception:
            pass
    return img


def get_material(atlas='world', rough=0.9):
    name = _ATLAS[atlas]['material']
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = (atlas == 'char')      # M_char: culling on, glTF doubleSided false. M_farm: off, doubleSided true (grass, flowers and banner are single planes)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location = (400, 0)
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.location = (100, 0)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = 0.0
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-300, 0)
    tex.name = 'Atlas'; tex.label = 'Atlas'
    tex.image = get_atlas_image(atlas)
    tex.interpolation = 'Linear'
    tex.extension = 'EXTEND'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return m


def get_emissive_material(atlas='world', strength=3.0):
    """M_emissive: Principled BSDF whose Emission Color is the atlas colour (glow cells use the same UV cell rules)."""
    m = bpy.data.materials.get('M_emissive') or bpy.data.materials.new('M_emissive')
    m.use_nodes = True
    m.use_backface_culling = False      # glTF doubleSided true, like M_farm
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location = (400, 0)
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.location = (100, 0)
    bsdf.inputs['Roughness'].default_value = 0.9
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-300, 0)
    tex.name = 'Atlas'; tex.label = 'Atlas'; tex.image = get_atlas_image(atlas)
    tex.interpolation = 'Linear'; tex.extension = 'EXTEND'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = strength
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return m


def assign_material(obj, faces, mat):
    """Put `faces` in material `mat` (added as an extra slot if obj does not have it yet)."""
    me = obj.data
    names = [m.name if m else None for m in me.materials]
    if mat.name not in names:
        me.materials.append(mat); names.append(mat.name)
    idx = names.index(mat.name)
    for i in faces:
        me.polygons[i].material_index = idx
    return idx


def use_material(obj, atlas='world', rough=0.9):
    """Slot 0 = M_farm / M_char for every face of obj (extra slots are removed)."""
    m = bpy.data.materials.get(_ATLAS[atlas]['material']) or get_material(atlas, rough)
    me = obj.data
    me.materials.clear()
    me.materials.append(m)
    for p in me.polygons:
        p.material_index = 0
    obj.active_material_index = 0
    return m


# ------------------------------------------------------------------ face selectors (object-local space)
def faces_where(obj, fn):
    return sorted(p.index for p in obj.data.polygons if fn(p))


def faces_normal(obj, direction, min_dot=0.7):
    d = Vector(direction).normalized()
    return faces_where(obj, lambda p: p.normal.dot(d) >= min_dot)


def faces_box(obj, lo, hi):
    """Faces whose centre lies in the box lo..hi (object-local metres). Use None for an open side."""
    def ok(p):
        c = p.center
        return all((lo[i] is None or c[i] >= lo[i] - 1e-6) and (hi[i] is None or c[i] <= hi[i] + 1e-6)
                   for i in range(3))
    return faces_where(obj, ok)


def faces_z(obj, zmin=None, zmax=None):
    return faces_box(obj, (None, None, zmin), (None, None, zmax))


def shells(obj):
    """Loose parts (connected shells) of the mesh, in object-local metres."""
    bm = bmesh.new(); bm.from_mesh(obj.data); bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        st, comp = [f0], []
        seen.add(f0.index)
        while st:
            f = st.pop(); comp.append(f.index)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index); st.append(g)
        vs = [v.co for i in comp for v in bm.faces[i].verts]
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        out.append(dict(faces=sorted(comp), min=mn, max=mx, size=mx - mn, centre=(mn + mx) / 2))
    bm.free()
    return out


def faces_shells(obj, fn):
    return sorted(i for s in shells(obj) if fn(s) for i in s['faces'])


def all_faces(obj):
    return list(range(len(obj.data.polygons)))


# ------------------------------------------------------------------ seams
def mark_seam_loop(obj, edge_pairs, clear=False):
    s = set(tuple(sorted(e)) for e in edge_pairs)
    n = 0
    for e in obj.data.edges:
        if tuple(sorted(e.vertices)) in s:
            e.use_seam = not clear; n += 1
    return n


# ------------------------------------------------------------------ the main job
def _islands(bm, group, angle_limit):
    """Connected components of `group`; connection is cut at seams and at edges sharper than angle_limit."""
    lim = math.cos(math.radians(angle_limit))
    seen, out = set(), []
    for f0 in sorted(group):
        if f0 in seen:
            continue
        stack, comp = [f0], []
        seen.add(f0)
        while stack:
            f = stack.pop(); comp.append(f)
            for e in bm.faces[f].edges:
                if e.seam:
                    continue
                for g in e.link_faces:
                    gi = g.index
                    if gi in group and gi not in seen and bm.faces[f].normal.dot(g.normal) >= lim:
                        seen.add(gi); stack.append(gi)
        out.append(comp)
    return out


def _flatten(bm, comp):
    """Gravity-aligned planar (or cylindrical) flattening of one island, in metres. Returns {loop: (u, v)}."""
    faces = [bm.faces[i] for i in comp]
    n = Vector(); cnt = 0; c = Vector()
    for f in faces:
        n += f.normal * f.calc_area()
        for v in f.verts:
            c += v.co; cnt += 1
    c /= max(cnt, 1)
    spread = 0.0
    if n.length > 1e-6:
        nn = n.normalized()
        spread = max(math.degrees(math.acos(max(-1.0, min(1.0, f.normal.dot(nn))))) for f in faces)
    res = {}
    if spread > 70 and any(Vector((f.normal.x, f.normal.y, 0)).length > 0.5 for f in faces):
        # tube or bulge: u = arc length around the vertical axis through the centroid, v = height
        rs = [math.hypot(l.vert.co.x - c.x, l.vert.co.y - c.y) for f in faces for l in f.loops]
        rmean = sum(rs) / len(rs)
        ang0 = math.atan2(faces[0].calc_center_median().y - c.y, faces[0].calc_center_median().x - c.x)
        for f in faces:
            fc = f.calc_center_median()
            fa = math.atan2(fc.y - c.y, fc.x - c.x)
            base = (fa - ang0) % (2 * math.pi)
            for l in f.loops:
                a = math.atan2(l.vert.co.y - c.y, l.vert.co.x - c.x)
                da = (a - fa + math.pi) % (2 * math.pi) - math.pi
                res[l] = ((base + da) * rmean, l.vert.co.z)
        return res
    nn = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))
    if abs(nn.z) > 0.8:
        s = 1.0 if nn.z > 0 else -1.0     # top or bottom: u = x, v = y (bottom mirrored so it reads from outside)
        for f in faces:
            for l in f.loops:
                res[l] = (l.vert.co.x * s, l.vert.co.y)
        return res
    up = Vector((0, 0, 1)) - nn * nn.z
    up.normalize()
    right = up.cross(nn)   # seen from outside the face, +u points to the viewer's right
    for f in faces:
        for l in f.loops:
            p = l.vert.co - c
            res[l] = (p.dot(right), p.dot(up))
    return res


def _fit(res, rect, fit, rotate, tile_m, tile_size_uv):
    if rotate:
        a = math.radians(rotate); ca, sa = math.cos(a), math.sin(a)
        res = {k: (u * ca - v * sa, u * sa + v * ca) for k, (u, v) in res.items()}
    xs = [p[0] for p in res.values()]; ys = [p[1] for p in res.values()]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    w, h = max(x1 - x0, 1e-9), max(y1 - y0, 1e-9)
    u0, v0, u1, v1 = rect
    cw, ch = u1 - u0, v1 - v0
    if fit == 'flat':
        return {k: ((u0 + u1) / 2, (v0 + v1) / 2) for k in res}
    if fit == 'stretch':
        sx, sy = cw / w, ch / h; ox, oy = u0, v0
    elif fit == 'uniform':
        s = min(cw / w, ch / h); sx = sy = s
        ox = u0 + (cw - w * s) / 2; oy = v0 + (ch - h * s) / 2
    elif fit == 'world':
        s = tile_size_uv / float(tile_m)           # UV per metre
        s = min(s, cw / w, ch / h)                 # never leave the tile
        sx = sy = s; ox = u0; oy = v0
    else:
        raise ValueError(fit)
    return {k: (ox + (u - x0) * sx, oy + (v - y0) * sy) for k, (u, v) in res.items()}


def assign(obj, faces, ref, atlas='world', fit='uniform', rotate=0, tile_m=None, angle_limit=60.0, mark_seams=True):
    """Put the faces' UV islands inside atlas cell `ref` (see module doc). Returns dict(faces, islands, cell)."""
    if obj.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    c = cell(ref, atlas)
    mname = _ATLAS[atlas]['material']
    me = obj.data
    if len(me.materials) != 1 or me.materials[0] is None or me.materials[0].name != mname:
        use_material(obj, atlas)
    bm = bmesh.new(); bm.from_mesh(me)
    bm.faces.ensure_lookup_table(); bm.edges.ensure_lookup_table()
    uvl = bm.loops.layers.uv.get('UVMap') or bm.loops.layers.uv.new('UVMap')
    group = set(faces)
    comps = _islands(bm, group, angle_limit)
    for comp in comps:
        res = _flatten(bm, comp)
        out = _fit(res, c.rect, fit, rotate, tile_m, c.full[2] - c.full[0])
        for l, (u, v) in out.items():
            l[uvl].uv = (u, v)
    if mark_seams:
        for comp in comps:
            cs = set(comp)
            for i in comp:
                for e in bm.faces[i].edges:
                    if any(g.index not in cs for g in e.link_faces):
                        e.seam = True
    bm.to_mesh(me); bm.free(); me.update()
    return dict(faces=len(group), islands=len(comps), cell=c.name)


def assign_object(obj, ref, **kw):
    return assign(obj, all_faces(obj), ref, **kw)


def assign_groups(obj, groups, atlas='world', **kw):
    """groups = {'walls': (face_list, 'pal_plaster'), ...}; ref may be (ref, {assign kwargs}). Returns cell_table(obj)."""
    for gname, (faces, ref) in groups.items():
        if not faces:
            print('lm_uv WARNING: empty group', obj.name, gname); continue
        extra = {}
        if isinstance(ref, tuple):
            ref, extra = ref
        assign(obj, faces, ref, atlas=atlas, **{**kw, **extra})
    return cell_table(obj, atlas)


# ------------------------------------------------------------------ read back, checks, tables
def _cell_of_uv(u, v, atlas='world'):
    a = _a(atlas); S = a['size_px']; px, py = u * S, (1 - v) * S
    for t in a.get('detail_tiles', []):
        x, y, w, h = t['px_rect']
        if x <= px < x + w and y <= py < y + h:
            return t['name'], -1, ''
    col, row = int(px // a['cell_px']), int(py // a['cell_px'])
    idx = row * a['cols'] + col
    for c in a['cells']:
        if c['index'] == idx:
            return c['name'], idx, c['hex']
    return 'none', idx, ''


def _poly_uv_centre(uv, p):
    pts = [uv.data[l].uv for l in p.loop_indices]
    return sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts), pts


def cell_table(obj, atlas='world'):
    me = obj.data
    uv = me.uv_layers.get('UVMap')
    if uv is None:
        return []
    rows = {}
    for p in me.polygons:
        u, v, _ = _poly_uv_centre(uv, p)
        name, idx, hx = _cell_of_uv(u, v, atlas)
        r = rows.setdefault((name, idx), dict(object=obj.name, cell=idx, name=name, hex=hx, faces=0))
        r['faces'] += 1
    return sorted(rows.values(), key=lambda r: (r['cell'] if r['cell'] >= 0 else 999, r['name']))


def check_padding(obj, atlas='world', eps=1e-5):
    me = obj.data; uv = me.uv_layers['UVMap']; bad = []
    for p in me.polygons:
        u, v, pts = _poly_uv_centre(uv, p)
        name, idx, hx = _cell_of_uv(u, v, atlas)
        try:
            c = cell(name if name.startswith('detail') else idx, atlas)
        except KeyError:
            bad.append(p.index); continue
        r = c.rect
        if any(q[0] < r[0] - eps or q[0] > r[2] + eps or q[1] < r[1] - eps or q[1] > r[3] + eps for q in pts):
            bad.append(p.index)
    return bad


def texel_density(obj, atlas='world'):
    """Mean atlas pixels per metre over the object's faces (sqrt of UV area / surface area, times atlas size)."""
    me = obj.data; uv = me.uv_layers['UVMap']; S = _a(atlas)['size_px']
    sa = su = 0.0
    for p in me.polygons:
        pts = [Vector(uv.data[l].uv) for l in p.loop_indices]
        a2 = sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y
                 for i in range(len(pts)))
        sa += p.area; su += abs(a2) / 2
    return math.sqrt(su / sa) * S if sa > 1e-9 and su > 0 else 0.0


def write_cell_table(rows, path):
    ext = os.path.splitext(path)[1].lower()
    cols = ['object', 'group', 'cell', 'name', 'hex', 'faces']
    rows = [dict(r) for r in rows]
    for r in rows:
        r.setdefault('group', '')
    if ext == '.json':
        json.dump(rows, open(path, 'w'), indent=1)
    elif ext == '.csv':
        with open(path, 'w') as f:
            f.write(','.join(cols) + '\n')
            for r in rows:
                f.write(','.join(str(r.get(c, '')) for c in cols) + '\n')
    else:
        with open(path, 'w') as f:
            f.write('| ' + ' | '.join(cols) + ' |\n|' + '---|' * len(cols) + '\n')
            for r in rows:
                f.write('| ' + ' | '.join(str(r.get(c, '')) for c in cols) + ' |\n')
    return path


def atlas_cells_markdown(atlas='world'):
    out = ['| Index | Col | Row | Name | Hex |', '|---|---|---|---|---|']
    for c in atlas_cells(atlas):
        out.append('| %d | %d | %d | `%s` | `%s` |' % (c.index, c.col, c.row, c.name, c.hex))
    return '\n'.join(out)


def save_cell_hexes(path, atlas='world'):
    json.dump({c.name: c.hex for c in atlas_cells(atlas)}, open(path, 'w'), indent=1)
    return path


def set_vertex_colors(obj, name, values, domain='CORNER'):
    """Create/replace Color Attribute `name` (byte colour). values: per loop (CORNER) or per vertex (POINT) RGBA."""
    me = obj.data
    a = me.color_attributes.get(name)
    if a is not None:
        me.color_attributes.remove(a)
    a = me.color_attributes.new(name, 'BYTE_COLOR', domain)
    flat = []
    for v in values:
        flat.extend(v)
    a.data.foreach_set('color', flat)
    return a


# ------------------------------------------------------------------ ambient occlusion baked into vertex colours
def get_ao_material(atlas='world'):
    """M_farm_ao = M_farm with the Color Attribute 'AO' multiplied into Base Color (needs bake_ao on every object that
    uses it: a missing attribute renders black in Blender). Travels in glTF as COLOR_0."""
    m = get_material(atlas)
    m.name = _ATLAS[atlas]['material'] + '_ao' if False else m.name
    ao = bpy.data.materials.get(_ATLAS[atlas]['material'] + '_ao') or m.copy()
    ao.name = _ATLAS[atlas]['material'] + '_ao'
    ao.use_backface_culling = False     # same as M_farm: glTF doubleSided true
    nt = ao.node_tree
    tex = nt.nodes['Atlas']
    bsdf = [n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    for l in list(nt.links):
        if l.to_node == bsdf and l.to_socket.name == 'Base Color':
            nt.links.remove(l)
    va = nt.nodes.get('AO') or nt.nodes.new('ShaderNodeVertexColor')
    va.name = 'AO'; va.label = 'AO'; va.layer_name = 'AO'; va.location = (-300, -250)
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


# ------------------------------------------------------------------ part 2: the face-group table
from mathutils import Vector

PLANKS = dict(fit='world', tile_m=1.0)           # detail_wood_planks at 256 px per metre
PLANKS_H = dict(fit='world', tile_m=1.0, rotate=90)


def S(fn):
    return lambda o: faces_shells(o, fn)


def N(d, dot=0.7):
    return lambda o: faces_normal(o, d, dot)


def Z(lo=None, hi=None):
    return lambda o: faces_z(o, lo, hi)


def axis_aligned(o):
    return faces_where(o, lambda p: max(abs(p.normal.x), abs(p.normal.y), abs(p.normal.z)) > 0.99)


def rest(o):
    return all_faces(o)


def thin_axis(sh):
    s = sh['size']
    return min(range(3), key=lambda i: s[i])


def recess_faces(o, shell_pred):
    """Deepest face on the recessed side of every thin kit piece (door panel, window glass)."""
    out = []
    for sh in shells(o):
        if not shell_pred(sh) or len(sh['faces']) < 10:
            continue
        a = thin_axis(sh)
        by_sign = {1: [], -1: []}
        for i in sh['faces']:
            p = o.data.polygons[i]
            if abs(p.normal[a]) > 0.99:
                by_sign[1 if p.normal[a] > 0 else -1].append(i)
        sgn = 1 if len(by_sign[1]) > len(by_sign[-1]) else -1
        fl = by_sign[sgn]
        if len(fl) < 2:
            continue
        out.append(min(fl, key=lambda i: sgn * o.data.polygons[i].center[a]))
    return sorted(out)


def kit14(sh):
    return len(sh['faces']) == 14 and min(sh['size']) < 0.12 and sh['size'].z < 1.0


def small(sh, m=0.12):
    return max(sh['size']) < m


def tall(sh, m=1.0):
    return sh['size'].z > m


def at_z(lo, hi):
    return lambda sh: sh['centre'].z >= lo and sh['centre'].z <= hi


SPEC = {
    # ------------------------------------------------------------------ props (Chapter 7)
    'prop_crate_small': [('panels', axis_aligned, 'detail_wood_planks', PLANKS), ('frame', rest, 'pal_wood_dark', {})],
    'prop_crate_large': [('panels', axis_aligned, 'detail_wood_planks', PLANKS), ('frame', rest, 'pal_wood_dark', {})],
    'prop_barrel': [('hoops', lambda o: sorted(set(Z(0.14, 0.31)(o)) | set(Z(0.59, 0.76)(o))), 'pal_iron_dark', {}),
                    ('lid', Z(0.8, None), 'pal_wood_light', {}),
                    ('staves', rest, 'pal_wood_mid', {})],
    'prop_bucket': [('handle', S(lambda s: s['centre'].z > 0.25 and s['size'].y < 0.1), 'pal_iron_dark', {}),
                    ('body', rest, 'pal_wood_mid', {})],
    'prop_sack': [('tie', Z(0.48, None), 'pal_straw_dark', {}), ('body', rest, 'pal_plaster_shade', {})],
    'prop_sign_post': [('post', S(lambda s: tall(s, 1.0) and s['size'].x < 0.1), 'pal_wood_dark', {}),
                       ('boards', rest, 'detail_wood_planks', PLANKS_H)],
    'prop_sign_hang': [('board', S(lambda s: len(s['faces']) > 20), 'detail_wood_planks', PLANKS_H),
                       ('bar', S(lambda s: s['size'].x > 0.8), 'pal_wood_dark', {}),
                       ('chains', rest, 'pal_iron_dark', {})],
    'tool_hoe': [('handle', S(lambda s: tall(s, 1.0)), 'pal_wood_mid', {}),
                 ('blade', S(lambda s: s['size'].x > 0.15), 'pal_steel', {}),
                 ('socket', rest, 'pal_iron_dark', {})],
    'tool_watering_can': [('handle', S(lambda s: s['centre'].x < -0.1), 'pal_iron_dark', {}),
                          ('rose', S(lambda s: s['centre'].z > 0.35 and s['centre'].x > 0.15), 'pal_brass', {}),
                          ('body', rest, 'pal_steel', {})],
    'tool_seed_bag': [('label', lambda o: faces_where(o, lambda p: p.normal.y < -0.95 and 0.08 < p.center.z < 0.22),
                       'pal_carrot_top', {}),
                      ('fold', Z(0.3, None), 'pal_plaster_shade', {}),
                      ('bag', rest, 'pal_plaster', {})],
    'prop_trough': [('legs', S(lambda s: s['size'].z < 0.2), 'pal_wood_dark', {}),
                    ('water', lambda o: faces_where(o, lambda p: p.normal.z > 0.95 and 0.17 < p.center.z < 0.23), 'pal_water_mid', {}),
                    ('inside', lambda o: faces_where(o, lambda p: 0.15 < p.normal.z < 0.3 and p.center.z > 0.3), 'pal_wood_dark', {}),
                    ('outside', rest, 'pal_wood_mid', {})],
    'prop_lantern': [('glow', S(lambda s: abs(s['centre'].x) < 0.02 and abs(s['centre'].y) < 0.02 and 0.1 < s['centre'].z < 0.2),
                      'pal_straw_light', {}),
                     ('ring', S(lambda s: s['centre'].z > 0.3 and len(s['faces']) > 20), 'pal_brass', {}),
                     ('frame', rest, 'pal_iron_dark', {})],
    'prop_hay_bale': [('straps', lambda o: faces_where(o, lambda p: p.area < 0.01 or (0.1 < abs(p.center.x) < 0.3 and abs(abs(p.center.x) - 0.18) < 0.02 and p.area > 0.085)),
                       'pal_straw_dark', {}),
                      ('bale', rest, 'pal_straw_mid', {})],
    # ------------------------------------------------------------------ structures (Chapter 8)
    'fence_post': [('cap', N((0, 0, 1), 0.9), 'pal_wood_pale', {}), ('post', rest, 'pal_wood_mid', {})],
    'fence_rail': [('post', S(lambda s: tall(s, 0.9)), 'pal_wood_mid', {}), ('rails', rest, 'pal_wood_light', {})],
    'fence_corner': [('rails', lambda o: faces_where(o, lambda p: p.area < 0.0055 and 0.28 < p.center.z < 0.78), 'pal_wood_light', {}),
                     ('post', rest, 'pal_wood_mid', {})],
    'fence_gate': [('posts', S(lambda s: s['size'].z > 0.8), 'pal_wood_mid', {}),
                   ('brace', S(lambda s: s['size'].z > 0.4 and s['size'].x > 0.8), 'pal_wood_pale', {}),
                   ('rails', rest, 'pal_wood_light', {})],
    'kit_door': [('knob', S(lambda s: small(s, 0.12)), 'pal_brass', {}),
                 ('panel', lambda o: recess_faces(o, lambda sh: True), 'pal_door_blue', {}),
                 ('frame', rest, 'pal_wood_dark', {})],
    'kit_window': [('glass', lambda o: recess_faces(o, kit14), 'pal_glass', {}),
                   ('frame', rest, 'pal_wood_dark', {})],
    'bld_farmhouse': [('walls', S(lambda s: s['size'].x > 5 and s['size'].z < 3 and s['min'].z < 0.1), 'pal_plaster', {}),
                      ('roof_slopes', lambda o: faces_shells(o, lambda s: s['min'].z > 2.5 and s['size'].x > 5) and
                       [i for i in faces_shells(o, lambda s: s['min'].z > 2.5 and s['size'].x > 5) if o.data.polygons[i].normal.z > 0.3], 'pal_roof_mid', {}),
                      ('roof_under', lambda o: [i for i in faces_shells(o, lambda s: s['min'].z > 2.5 and s['size'].x > 5) if o.data.polygons[i].normal.z < -0.9], 'pal_roof_dark', {}),
                      ('gables', lambda o: [i for i in faces_shells(o, lambda s: s['min'].z > 2.5 and s['size'].x > 5) if abs(o.data.polygons[i].normal.x) > 0.9], 'pal_plaster_shade', {}),
                      ('chimney_top', lambda o: [i for i in faces_shells(o, lambda s: s['min'].z > 2.9 and s['size'].x < 1) if o.data.polygons[i].center.z > 5.35], 'pal_iron_dark', {}),
                      ('chimney', S(lambda s: s['min'].z > 2.9 and s['size'].x < 1), 'pal_brick', {}),
                      ('step', S(lambda s: s['max'].z < 0.2 and s['size'].x > 1), 'pal_stone_mid', {}),
                      ('knob', S(lambda s: small(s, 0.1)), 'pal_brass', {}),
                      ('glass', lambda o: recess_faces(o, kit14), 'pal_glass', {}),
                      ('door_panel', lambda o: [i for i in recess_faces(o, lambda s: s['size'].z > 1.8)], 'pal_door_blue', {}),
                      ('trim', rest, 'pal_wood_dark', {})],
    'bld_barn': [('doors', S(lambda s: s['size'].x < 3 and s['min'].z < 0.1), 'pal_plaster', {}),
                 ('roof_gables', lambda o: [i for i in faces_shells(o, lambda s: s['min'].z > 4) if abs(o.data.polygons[i].normal.y) > 0.9], 'pal_roof_dark', {}),
                 ('roof', S(lambda s: s['min'].z > 4), 'pal_iron_dark', {}),
                 ('walls', rest, 'pal_roof_dark', {})],
    'bld_shed': [('roof', S(lambda s: s['min'].z > 1.9 and s['size'].x > 2.9), 'pal_roof_dark', {}),
                 ('knob', S(lambda s: small(s, 0.1)), 'pal_brass', {}),
                 ('glass', lambda o: recess_faces(o, kit14), 'pal_glass', {}),
                 ('door_panel', lambda o: [i for i in recess_faces(o, lambda s: s['size'].z > 1.8)], 'pal_wood_pale', {}),
                 ('trim', S(lambda s: len(s['faces']) <= 14 and s['size'].x < 1.0), 'pal_wood_dark', {}),
                 ('walls', rest, 'pal_wood_light', {})],
    'bld_chicken_coop': [('roof', S(lambda s: s['min'].z > 1.3), 'pal_roof_mid', {}),
                         ('legs', S(lambda s: s['max'].z <= 0.5 and len(s['faces']) == 10), 'pal_wood_dark', {}),
                         ('ramp', S(lambda s: s['max'].z <= 0.5 and len(s['faces']) == 6), 'pal_wood_light', {}),
                         ('lid', S(lambda s: len(s['faces']) == 6 and s['min'].z >= 1.0), 'pal_wood_dark', {}),
                         ('nest', S(lambda s: len(s['faces']) == 6), 'pal_wood_mid', {}),
                         ('walls', rest, 'pal_wood_pale', {})],
    'bld_well': [('posts', S(lambda s: len(s['faces']) == 10), 'pal_wood_dark', {}),
                 ('roof', S(lambda s: s['min'].z > 1.9), 'pal_roof_mid', {}),
                 ('beam', S(lambda s: s['size'].x > 1.2 and s['size'].z < 0.2), 'pal_wood_mid', {}),
                 ('rope', S(lambda s: len(s['faces']) == 6 and s['size'].z > 0.4), 'pal_straw_dark', {}),
                 ('bucket', S(lambda s: 0.8 < s['min'].z < 0.9), 'pal_wood_light', {}),
                 ('ring_top', N((0, 0, 1), 0.9), 'pal_stone_light', {}),
                 ('ring_in', lambda o: faces_where(o, lambda p: abs(p.normal.z) < 0.5 and p.normal.x * p.center.x + p.normal.y * p.center.y < -0.01), 'pal_stone_dark', {}),
                 ('ring', rest, 'pal_stone_mid', {})],
    'farmstead_ground': [('ground', rest, 'pal_grass_mid', dict(fit='flat'))],
}


def apply_spec(o, spec=None, log=None):
    """Run the SPEC of object `o` (first match wins); returns list of rows for the book table."""
    spec = spec or SPEC[o.name]
    done = set()
    rows = []
    use_material(o)
    for gname, sel, ref, kw in spec:
        fs = [i for i in sel(o) if i not in done]
        if not fs:
            print('  WARNING empty group', o.name, gname)
            continue
        r = assign(o, fs, ref, **kw)
        done.update(fs)
        c = cell(ref)
        rows.append(dict(object=o.name, group=gname, cell=c.index if c.index >= 0 else c.name.replace('detail_', 'tile:'),
                         name=c.name, hex=c.hex, faces=len(fs), islands=r['islands']))
    left = len(o.data.polygons) - len(done)
    if left:
        print('  WARNING', o.name, left, 'faces left unassigned')
    return rows


# ------------------------------------------------------------------ part 3: run the table
SKIP_IF_DONE = {'prop_crate_small', 'bld_farmhouse'}     # the two assets you texture by hand in Chapter 9


def run_all(force=False):
    done = set()
    rows = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or o.name not in SPEC or o.data.name in done:
            continue
        done.add(o.data.name)
        if o.name in SKIP_IF_DONE and not force and o.data.materials and o.data.materials[0] and o.data.materials[0].name == 'M_farm':
            print('skipped (already done by hand):', o.name)
            continue
        rows += apply_spec(o)
        print(o.name, 'done,', len(o.data.polygons), 'faces,', 'padding problems:', check_padding(o))
    lan = bpy.data.objects.get('prop_lantern')
    if lan:
        shp = [s for s in shells(lan) if abs(s['centre'].x) < 0.02 and abs(s['centre'].y) < 0.02 and 0.1 < s['centre'].z < 0.2]
        assign_material(lan, [i for s in shp for i in s['faces']], get_emissive_material())
    return rows


run_all()
