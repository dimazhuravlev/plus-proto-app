#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Волна «подъёма» по поверхности (`LiftWave.swift`): от точки касания расходится кольцо,
// и на его гребне картинка чуть крупнее — глаз читает это как поверхность, приподнятую
// к нему волной (ripple-эффект iOS). Передний склон светлее, задний темнее — у волны
// появляется объём. Ничего не поднимается по z: это линза и свет на плоском растре.
//
// Огибающая — с нуля и в ноль: в первый и последний кадр пиксели исходные, и включение
// и выключение эффекта бесшовны.

[[ stitchable ]] half4 liftWave(float2 position, SwiftUI::Layer layer,
                                float2 origin, float time,
                                float speed, float width, float amplitude,
                                float shade, float flash,
                                float duration) {
    float2 delta = position - origin;
    float radius = length(delta);
    float2 direction = radius > 0.0 ? delta / radius : float2(0.0);

    // Где точка относительно гребня, в ширинах гребня: < 0 — позади, > 0 — впереди.
    float x = (radius - time * speed) / width;
    float bump = exp(-x * x);

    // Сила — симметричный колокол sin² на всю длительность: нарастает и гаснет одинаково
    // плавно, с нулевой скоростью на обоих концах, пик посередине.
    float bell = sin(M_PI_F * saturate(time / duration));
    float envelope = bell * bell;

    // Линза: выборка с обеих сторон стягивается к гребню — на гребне картинка крупнее.
    // `x * bump` по модулю не больше 0.43 — смещение не больше половины `amplitude`.
    float2 source = position - direction * amplitude * envelope * x * bump;
    half4 color = layer.sample(source);

    // Свет: впереди гребня ярче, позади темнее (производная горба). `flash` — ровная
    // вспышка без движения, ветка «уменьшения движения». Цвет с умноженной альфой —
    // каналы не выше альфы, иначе полупрозрачный край капли светился бы сильнее середины.
    // Границы — от исходного канала: цвет палитры в P3 приходит расширенным (ниже нуля,
    // выше альфы), и свет не срезает его до охвата sRGB, а только не уводит дальше.
    float light = envelope * (shade * 2.0 * x * bump + flash);
    half3 lit = color.rgb + half(light) * color.a;
    color.rgb = clamp(lit, min(color.rgb, half3(0.0)), max(color.rgb, half3(color.a)));
    return color;
}
