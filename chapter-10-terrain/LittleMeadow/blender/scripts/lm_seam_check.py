"""lm_seam_check.py : Chapter 10.  Checks that neighbouring terrain tiles of COL_terrain_layout meet with no gap.
Open lm_terrain.blend, open this file in the Text Editor of the Scripting workspace, press Run Script.
For every pair of tiles that share an edge it reads the height along both copies of the edge at 101 points
and prints the largest difference in metres."""
import bpy

TILE = 4.0
N = 101


def edge_heights(o, side):
    """Heights z at N evenly spaced points along one edge of tile o (side E, W, N or S), in world space."""
    mw = o.matrix_world
    pts = [mw @ v.co for v in o.data.vertices]
    cx, cy = o.location.x, o.location.y
    h = TILE / 2
    if side in 'EW':
        x0 = cx + (h if side == 'E' else -h)
        line = sorted((p.y, p.z) for p in pts if abs(p.x - x0) < 1e-4)
        lo, hi = cy - h, cy + h
    else:
        y0 = cy + (h if side == 'N' else -h)
        line = sorted((p.x, p.z) for p in pts if abs(p.y - y0) < 1e-4)
        lo, hi = cx - h, cx + h
    out = []
    for q in range(N):
        t = lo + (hi - lo) * q / (N - 1)
        for (a, za), (b, zb) in zip(line, line[1:]):
            if a - 1e-6 <= t <= b + 1e-6:
                out.append(za + (zb - za) * (0 if b == a else (t - a) / (b - a)))
                break
        else:
            out.append(float('nan'))
    return out


def run():
    bpy.context.view_layer.update()
    tiles = {}
    for o in bpy.data.collections['COL_terrain_layout'].objects:
        tiles[(round(o.location.x / TILE), round((o.location.y - 10) / TILE))] = o
    worst, pairs = 0.0, 0
    for (i, j), o in tiles.items():
        for (di, dj, a, b) in ((1, 0, 'E', 'W'), (0, 1, 'N', 'S')):
            nb = tiles.get((i + di, j + dj))
            if nb is None:
                continue
            d = max(abs(x - y) for x, y in zip(edge_heights(o, a), edge_heights(nb, b)))
            worst = max(worst, d)
            pairs += 1
            print('%-22s %-22s %s %.8f m' % (o.name, nb.name, a + b, d))
    print('pairs', pairs, 'worst difference', worst, 'm')


run()
