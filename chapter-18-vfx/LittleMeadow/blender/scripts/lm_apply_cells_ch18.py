"""lm_apply_cells_ch18.py : Chapter 18.  Puts the banner and its pole of lm_vfx.blend on the palette atlas (Chapter 9 method).
Open lm_vfx.blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
It loads the helper library of lm_apply_cells.py (same folder), then runs the face-group table of Chapter 18."""
import bpy
_lib = bpy.path.abspath('//scripts/lm_apply_cells.py')
exec(compile(open(_lib).read().split('SPEC = {')[0], _lib, 'exec'))      # part 1 + the selectors of part 2


SPEC = {
    'vfx_banner_pole': [('wood', rest, 'wood_mid', {})],
    'vfx_banner':      [('cloth', rest, 'tractor_red', dict(fit='stretch'))],
}


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
