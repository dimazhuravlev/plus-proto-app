#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bundle the recorded clips with an offline player and captions outside video."""
import html
import json
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output/mix-motion"
ITEMS = [
    ("petal-press", "Лепесток: нажатие без линзы", "Нажатие использует штатный PressScaleEffect: масштаб 1→0,97 и возврат. Волна-линза выключена, дыхание включено."),
    ("petal-wave", "Лепесток: запуск", "SwiftUI: keyframeAnimator задаёт время, layerEffect применяет Metal-шейдер ShaderLibrary.liftWave. Волна идёт из точки нажатия за 1,3 с; дыхание включено."),
    ("petal-breath", "Только дыхание", "Пульсация масштаба, покачивание и свечение. Цикл дыхания — 4,8 с."),
    ("swipe-flat", "Листание без объёма", "Флаг объёма и параллакса выключен. Остаются масштаб, сдвиг и плоский наклон."),
    ("swipe-depth", "Листание с объёмом", "SwiftUI: visualEffect читает положение в ScrollView; два rotation3DEffect поворачивают карточку вокруг X/Y с perspective 0,6; offset создаёт параллакс слоёв. Масштаб — scaleEffect."),
    ("like", "Лайк", "Сначала штатное нажатие: масштаб 1→0,92, затем отпускание и сворачивание. Кнопка белеет; реакции скрываются, карточка остаётся."),
    ("dislike", "Дизлайк", "Карточка растворяется с блюром; соседняя занимает её место, ряд схлопывается."),
    ("save", "Сохранение · V2", "Флаг V2 включён. Кнопка сначала проседает до 0,92; при отпускании сохраняет в «Моё», сворачивается, затем реакции скрываются."),
    ("glow", "Смена свечения", "Непрозрачность карточек, подписей и реакций — 0%. Видны только смешивание фонового свечения и кружок свайпа."),
    ("petal-pause", "Остановка лепестка", "Дыхание мягко возвращает форму в исходное состояние за 450 мс."),
    ("neighbor", "Тап по соседу", "Соседняя карточка доезжает в центр за 400 мс; затем появляются её подписи и реакции."),
    ("entrance", "Первое появление", "Карусель проявляется и поднимается на 24 pt за 500 мс."),
    ("toast", "Исчезновение тоста", "Автоскрытие уведомления: затухание и размытие за 500 мс."),
    ("intro", "Сворачивание подсказки", "Штатная просадка при нажатии и отпускание; затем капсула «Рекомендовать» сужается за 600 мс и появляется «Новое»."),
    ("open", "Открытие и возврат", "Нативный зум из обложки в экран альбома и обратно в карусель."),
]


def main():
    manifest = []
    cards = []
    for name, title, caption in ITEMS:
        path = OUTPUT / (name + ".mp4")
        if not path.is_file():
            raise FileNotFoundError(path)
        manifest.append(dict(file=path.name, title=title, caption=caption,
                             duration_seconds=4.9, bytes=path.stat().st_size))
        cards.append(
            f'<article><h2>{html.escape(title)}</h2>'
            f'<video controls playsinline muted loop preload="metadata" '
            f'poster="previews/{name}-0.jpg?v={path.stat().st_mtime_ns}" src="{name}.mp4?v={path.stat().st_mtime_ns}"></video>'
            f'<p>{html.escape(caption)}</p><a href="{name}.mp4" download>Скачать MP4</a></article>'
        )
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    page = '''<!doctype html><html lang="ru"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Анимации микс-карусели</title><style>
*{box-sizing:border-box}body{margin:0;background:#111;color:#eee;font:16px/1.5 system-ui}
header,main{max-width:1320px;margin:auto;padding:24px}h1{font-size:30px;margin:0 0 8px}
header p{color:#aaa;margin:0}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;padding-top:0}
article{background:#1c1c1c;border-radius:18px;overflow:hidden;padding:16px;display:flex;flex-direction:column;gap:12px}
h2{font-size:18px;margin:0}video{width:100%;height:auto;max-height:410px;background:#000;border-radius:10px}
article p{margin:0;color:#bbb;font-size:14px}a{color:#c9b4ff;font-size:14px;margin-top:auto}
</style><header><h1>Анимации микс-карусели</h1>
<p>15 отдельных роликов · каждый 4,9 с · запись локального прототипа · Recently выключена</p>
<p>Белый кружок показывает целевой элемент; при листании он движется в сторону свайпа. Сценарии запускают штатные обработчики программно. Пояснения расположены вне видео.</p>
</header><main>'''
    (OUTPUT / "index.html").write_text(page + "".join(cards) + "</main></html>", encoding="utf-8")
    (OUTPUT / "index-with-touches.html").write_text((OUTPUT / "index.html").read_text(encoding="utf-8"), encoding="utf-8")
    archive = OUTPUT / "mix-carousel-animations.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name, _, _ in ITEMS:
            for relative in (name + ".mp4", f"previews/{name}-0.jpg"):
                bundle.write(OUTPUT / relative, relative)
        for relative in ("index.html", "manifest.json"):
            bundle.write(OUTPUT / relative, relative)
    print(f"Packaged {len(ITEMS)} videos: {archive} ({archive.stat().st_size / 1024**2:.1f} MiB)")


if __name__ == "__main__":
    main()
