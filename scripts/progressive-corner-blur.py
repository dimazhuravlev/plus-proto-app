"""Прогрессивный блюр верхнего левого угла иллюстрации станции «Моей волны» (макет
2688:26278: в Figma это слой фонового блюра — SVG и PNG-экспорт его не передают).
Максимум в углу, к антидиагонали (x/W + y/H = 1) — ноль; запекаем в PNG с прозрачным полем.

python3 scripts/progressive-corner-blur.py <in.png> <out.png> <sigma_max_px> <pad_px>
(иллюстрации станций: sigma 22, pad 30 при растре @3x; нужны numpy и Pillow)
"""
import sys, numpy as np
from PIL import Image, ImageFilter
src, dst, sigma_max, pad = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert('RGBA')
W, H = im.size
canvas = Image.new('RGBA', (W + 2 * pad, H + 2 * pad), (0, 0, 0, 0))
canvas.paste(im, (pad, pad))
a = np.asarray(canvas).astype(np.float64) / 255.0
pm = a.copy(); pm[..., :3] *= pm[..., 3:4]          # премультипликация — без тёмных ореолов
levels = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
stack = []
for f in levels:
    s = sigma_max * f
    if s < 0.01:
        stack.append(pm); continue
    img = Image.fromarray((pm * 255).round().astype(np.uint8))
    chans = [np.asarray(c.filter(ImageFilter.GaussianBlur(s))).astype(np.float64) / 255.0 for c in img.split()]
    stack.append(np.stack(chans, -1))
yy, xx = np.mgrid[0:H + 2 * pad, 0:W + 2 * pad].astype(np.float64)
u = (xx - pad) / W + (yy - pad) / H                  # 0 — угол, 1 — антидиагональ
m = np.clip(1 - u, 0, 1)
m = m * m * (3 - 2 * m)                              # smoothstep
idx = m * (len(levels) - 1)
lo = np.floor(idx).astype(int); hi = np.minimum(lo + 1, len(levels) - 1); t = (idx - lo)[..., None]
S = np.stack(stack, 0)
out = np.take_along_axis(S, lo[None, ..., None].repeat(4, -1), 0)[0] * (1 - t) + \
      np.take_along_axis(S, hi[None, ..., None].repeat(4, -1), 0)[0] * t
alpha = out[..., 3:4]
rgb = np.where(alpha > 1e-6, out[..., :3] / np.maximum(alpha, 1e-6), 0)
res = np.concatenate([rgb, alpha], -1)
Image.fromarray((np.clip(res, 0, 1) * 255).round().astype(np.uint8)).save(dst)
