"""Перекраска SVG агента «Моей волны» из Figma в другой цвет палитры: основной цвет заливки
и матрицы цвета внутренних теней (основной и светлый). Дальше — scripts/svg-raster.py.

python3 -I scripts/svg-recolor.py <src.svg> <out.svg> <base_from> <light_from> <base_to> <light_to>
"""
import re, sys
src, out, bf, lf, bt, lt = sys.argv[1:7]
s = open(src).read()
def rgb(h): return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def close(a, b): return all(abs(x - y) < 0.01 for x, y in zip(a, b))
B, L, BT, LT = rgb(bf), rgb(lf), rgb(bt), rgb(lt)
s = s.replace(f'fill="#{bf}"', f'fill="#{bt}"')
def fix(m):
    v = [float(x) for x in m.group(1).split()]
    c = (v[4], v[9], v[14])
    if close(c, B): t = BT
    elif close(c, L): t = LT
    else: return m.group(0)
    v[4], v[9], v[14] = t
    return 'values="' + ' '.join(('%g' % x) for x in v) + '"'
s = re.sub(r'values="([^"]+)"', fix, s)
open(out, 'w').write(s)
