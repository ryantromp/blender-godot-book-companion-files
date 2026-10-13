"""lm_apply_cells_ch11.py : Chapter 11.  Puts the vegetation assets of lm_vegetation.blend on the palette atlas (Chapter 9 method).
Open lm_vegetation.blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
It loads the helper library of lm_apply_cells.py (same folder), then runs the face-group table of Chapter 11."""
import bpy
_lib = bpy.path.abspath('//scripts/lm_apply_cells.py')
exec(compile(open(_lib).read().split('SPEC = {')[0], _lib, 'exec'))      # part 1 + the selectors of part 2


def mound(sh):   return sh['min'].z < 0.001 and sh['max'].z < 0.06 and sh['size'].x > 0.2
def thin(sh):    return sh['size'].x < 0.6 and sh['min'].z < 0.001          # the trunk
def high(z):     return lambda sh: sh['centre'].z > z
def low(z):      return lambda sh: sh['centre'].z < z


SPEC = {
    'tree_pine':  [('trunk', S(thin), 'bark', {}), ('needles', rest, 'pine', {})],
    'tree_oak':   [('trunk', S(thin), 'bark', {}), ('canopy_top', S(high(3.9)), 'leaf_light', {}), ('canopy', rest, 'leaf_dark', {})],
    'bush':       [('bush_light', S(lambda sh: sh['centre'].x > 0.15), 'leaf_light', {}), ('bush', rest, 'hedge', {})],
    'flower_a':   [('petals', S(lambda sh: sh['size'].x > 0.12), 'flower_pink', {}), ('centre', S(lambda sh: sh['centre'].z > 0.2 and sh['size'].x < 0.12), 'flower_yellow', {}),
                   ('leaves', S(lambda sh: sh['max'].z < 0.15), 'leaf_light', {}), ('stem', rest, 'leaf_dark', {})],
    'flower_b':   [('cup', S(high(0.22)), 'flower_purple', {}), ('leaves', S(lambda sh: sh['max'].z < 0.2 and sh['size'].x > 0.03), 'leaf_light', {}), ('stem', rest, 'leaf_dark', {})],
    'flower_c':   [('bloom', S(high(0.2)), 'flower_white', {}), ('leaves', S(lambda sh: sh['max'].z < 0.2 and sh['size'].x > 0.03), 'leaf_light', {}), ('stem', rest, 'leaf_dark', {})],
    'grass_tuft': [('blades', rest, 'grass_light', dict(fit='stretch'))],
}
for _i in range(4):
    SPEC['crop_carrot_s%d' % _i] = [('root', S(lambda sh: 0.03 < sh['centre'].z < 0.1 and sh['size'].x < 0.12 and sh['size'].z < 0.08 and sh['min'].z > 0.04), 'carrot', {}),
                                    ('mound', S(mound), 'soil_mid', {}), ('tops', rest, 'carrot_top', {})]
    SPEC['crop_wheat_s%d' % _i] = [('ears', S(lambda sh: sh['centre'].z > 0.7), 'wheat_gold', {}), ('mound', S(mound), 'soil_mid', {}),
                                   ('stalks', rest, 'straw_mid' if _i == 3 else 'grass_hi', {})]
    SPEC['crop_pumpkin_s%d' % _i] = [('fruit', S(lambda sh: sh['size'].x > 0.15 and sh['size'].z > 0.15), 'pumpkin', {}), ('mound', S(mound), 'soil_mid', {}),
                                     ('stem', S(lambda sh: sh['size'].x < 0.08 and sh['centre'].z > 0.3), 'leaf_dark', {}), ('leaves', rest, 'leaf_light', {})]


def apply_spec(o):
    done, rows = set(), []
    for gname, sel, ref, kw in SPEC[o.name]:
        fs = [i for i in sel(o) if i not in done]
        if not fs:
            continue
        r = assign(o, fs, ref, **kw)
        done.update(fs)
        c = cell(ref)
        rows.append(dict(object=o.name, group=gname, cell=c.index, name=c.name, hex=c.hex, faces=len(fs), islands=r['islands']))
    left = len(o.data.polygons) - len(done)
    if left:
        print('  WARNING', o.name, left, 'faces left unassigned')
    return rows


rows = []
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name in SPEC:
        rows += apply_spec(o)
        print(o.name, 'done,', len(o.data.polygons), 'faces, padding problems:', check_padding(o))
