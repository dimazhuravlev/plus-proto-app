"""SVG с фильтрами → PNG с альфой. Quick Look (WebKit) рисует фильтры, но на сплошном
фоне и в своём масштабе: рендерим крупно на чёрном и на белом холсте, находим холст по
чёрной заливке, вырезаем, уменьшаем до нужного размера и восстанавливаем альфу по разнице.

python3 -I matte.py <svg> <out.png> <scale>
"""
import os, re, subprocess, sys, tempfile

svg_path, out_path, scale = sys.argv[1], sys.argv[2], float(sys.argv[3])
src = open(svg_path).read()
w = float(re.search(r'width="([0-9.]+)"', src).group(1))
h = float(re.search(r'height="([0-9.]+)"', src).group(1))
pw, ph = round(w * scale), round(h * scale)
big = 4.0  # рендер с запасом, потом уменьшаем до `scale`
cw, ch = round(w * big), round(h * big)
inner = re.sub(r"^<svg", '<svg x="0" y="0"', src.strip(), count=1)


def render(bg):
    d = tempfile.mkdtemp()
    p = os.path.join(d, "a.svg")
    open(p, "w").write(
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{cw}" height="{ch}">'
        f'<rect x="0" y="0" width="{cw}" height="{ch}" fill="{bg}"/>'
        f'<g transform="scale({big})">{inner}</g></svg>')
    subprocess.run(["qlmanage", "-t", "-s", str(max(cw, ch) * 2), "-o", d, p],
                   capture_output=True, check=True)
    return p + ".png"


def size(png):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height", "-of", "csv=p=0", png], capture_output=True, text=True).stdout
    a, b = out.strip().split(",")
    return int(a), int(b)


black_png, white_png = render("black"), render("white")
iw, ih = size(black_png)
raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", black_png, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                     capture_output=True, check=True).stdout
# Холст — где чёрный рендер не белый (поле Quick Look вокруг — белое).
max_x = max_y = 0
for y in range(ih):
    row = raw[y * iw * 3:(y + 1) * iw * 3]
    for x in range(iw):
        if row[x * 3] < 250 or row[x * 3 + 1] < 250 or row[x * 3 + 2] < 250:
            if x > max_x:
                max_x = x
            max_y = y
bw, bh = max_x + 1, max_y + 1


def scaled(png):
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", png, "-vf",
                           f"crop={bw}:{bh}:0:0,scale={pw}:{ph}:flags=lanczos",
                           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout


black, white = scaled(black_png), scaled(white_png)
out = bytearray()
for i in range(0, len(black), 3):
    b = black[i:i + 3]
    wt = white[i:i + 3]
    a = 255 - max(0, min(255, round(sum(wt[c] - b[c] for c in range(3)) / 3)))
    px = (i // 3) % pw
    py = (i // 3) // pw
    # Кромка холста при вырезании сглаживается в полупрозрачную линию — у иконок по
    # краям пустое поле, гасим два крайних пикселя.
    if a <= 2 or px >= pw - 2 or py >= ph - 2 or px < 2 or py < 2:
        out += bytes((0, 0, 0, 0))
    else:
        out += bytes(min(255, round(b[c] * 255 / a)) for c in range(3)) + bytes((a,))
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba",
                "-s", f"{pw}x{ph}", "-i", "-", out_path], input=bytes(out), check=True)
print(f"{os.path.basename(out_path)}: {pw}x{ph} (холст в рендере {bw}x{bh} из {iw}x{ih})")
