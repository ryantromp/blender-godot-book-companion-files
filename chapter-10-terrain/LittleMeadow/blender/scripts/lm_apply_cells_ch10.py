"""lm_apply_cells_ch10.py : Chapter 10.  Puts the terrain assets of lm_terrain.blend on the palette atlas (Chapter 9 method).
Open lm_terrain.blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
It loads the helper library of lm_apply_cells.py (same folder), then runs the face-group table of Chapter 10."""
import bpy
_lib = bpy.path.abspath('//scripts/lm_apply_cells.py')
exec(compile(open(_lib).read().split('SPEC = {')[0], _lib, 'exec'))      # part 1 + the selectors of part 2

FLAT = dict(fit='flat')      # one flat colour, so neighbouring tiles match exactly

SPEC = {
    'ter_tile_flat':   [('grass', rest, 0, FLAT)],
    'ter_tile_slope':  [('grass', rest, 0, FLAT)],
    'ter_tile_corner': [('grass', rest, 0, FLAT)],
    'path_straight':   [('top', N((0, 0, 1)), 12, {}), ('edge', rest, 10, {})],
    'path_corner':     [('top', N((0, 0, 1)), 12, {}), ('edge', rest, 10, {})],
    'field_plot':      [('top', N((0, 0, 1)), 10, {}), ('sides', rest, 9, {})],
    'ter_pond':        [('floor', Z(None, -0.2), 11, {}), ('bank', Z(-0.2, -0.04), 9, {}), ('rim', rest, 0, FLAT)],
    'ter_pond__water': [('water', rest, 32, {})],
    'rock_a':          [('top', N((0, 0, 1), 0.5), 15, {}), ('body', rest, 14, {})],
    'rock_b':          [('top', N((0, 0, 1), 0.5), 14, {}), ('body', rest, 13, {})],
    'rock_c':          [('top', N((0, 0, 1), 0.5), 15, {}), ('body', rest, 13, {})],
    'cliff_straight':  [('grass_top', lambda o: sorted(set(N((0, 0, 1), 0.5)(o)) & set(Z(2.0, None)(o))), 0, FLAT),
                        ('foot', Z(None, 0.7), 13, {}), ('crown', Z(2.0, None), 15, {}), ('wall', rest, 14, {})],
    'cliff_corner':    [('grass_top', lambda o: sorted(set(N((0, 0, 1), 0.5)(o)) & set(Z(2.0, None)(o))), 0, FLAT),
                        ('foot', Z(None, 0.7), 13, {}), ('crown', Z(2.0, None), 15, {}), ('wall', rest, 14, {})],
}


def apply_spec(o):
    done, rows = set(), []
    for gname, sel, ref, kw in SPEC[o.name]:
        fs = [i for i in sel(o) if i not in done]
        if not fs:
            print('  WARNING empty group', o.name, gname)
            continue
        r = assign(o, fs, ref, **kw)
        done.update(fs)
        c = cell(ref)
        rows.append(dict(object=o.name, group=gname, cell=c.index, name=c.name, hex=c.hex, faces=len(fs), islands=r['islands']))
    return rows


rows = []
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name in SPEC:
        rows += apply_spec(o)
        print(o.name, 'done,', len(o.data.polygons), 'faces, padding problems:', check_padding(o))
