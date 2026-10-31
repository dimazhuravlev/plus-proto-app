#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Голографический блик обложки (`CoverHolo.swift`, просьба пользователя
// 2026-10-31). Едва заметный глянец: мягкая полоса белого света, по краям которой
// переливается спектр, как у дифракционной фольги. Полоса бежит за наклоном телефона
// (`light`), цвета текут быстрее неё. При `amount = 0` пиксель возвращается как есть:
// вход и уход эффекта бесшовны.
//
// Считается в рабочем пространстве слоя — гамма-sRGB с умноженной альфой: силы ниже
// подобраны на глаз по превью на обложках проекта, а не в физических единицах.

namespace album_cover_holo {
    // Полоса бежит к правому нижнему углу (нормаль — normalize(4, 3)), сама идёт
    // снизу слева вверх вправо, чуть круче диагонали.
    constant float2 kNormal = float2(0.8, 0.6);
    constant float2 kAlong = float2(-0.6, 0.8);
    // Покой — у левого верхнего угла (свет сверху слева): на обложке только край
    // глянца, середина чистая.
    constant float2 kRest = float2(-0.53, -0.32);
    // Полосы повторяются через 1.7 обложки: наклон в обратную сторону уводит первую
    // и приводит следующую из правого нижнего угла — блик пробегает в обе стороны.
    constant float kPeriod = 1.7;
    // Профиль в долях обложки (сигмы гаусса): сияние, ядро глянца, затухание к концам —
    // мягкая полоса, а не белый штрих от края до края.
    constant float kSigmaBand = 0.16;
    constant float kSigmaCore = 0.06;
    constant float kSigmaAlong = 0.8;
    // Цвет — на краях полосы, к центру свет белеет: так светится кромка дифракции.
    constant float kFringeFrom = 0.02;
    constant float kFringeTo = 0.14;
    // Фаза спектра в циклах: поперёк полосы, вдоль неё, от яркости пикселя (переливы
    // гнутся по рисунку обложки) и от пробега блика (цвета текут быстрее полосы).
    constant float kHueAcross = 1.4;
    constant float kHueAlong = 0.25;
    constant float kHueInk = 0.35;
    constant float kHueFlow = 0.8;
    // Сила: белый свет ядра и сияния (пик на чёрном — +0.10), цвет (±0.05 на канал).
    constant float kCore = 0.06;
    constant float kSheen = 0.04;
    constant float kChroma = 0.10;
    // Доля цвета по всему сиянию; остальное — только на краях полосы.
    constant float kChromaEverywhere = 0.35;
    constant float3 kLuma = float3(0.2126, 0.7152, 0.0722);
}

/// `bounds` — кадр вью эффекта (`.boundingRect`), `margin` — прозрачное поле вокруг обложки
/// в нём; `light` — сдвиг блика от покоя в долях обложки (x вправо, y вниз); `hue` — дрейф
/// фазы спектра в циклах; `amount` — огибающая × сила; `scale` — пикселей в пункте (дизер).
[[ stitchable ]] half4 coverHolo(float2 position, half4 color, float4 bounds, float margin,
                                      float2 light, float hue, float amount, float scale) {
    using namespace album_cover_holo;
    if (amount <= 0.0 || color.a <= 0.0h) {
        return color;
    }

    // Цвет приходит с умноженной альфой — на кромке скругления снимаем её и возвращаем.
    float alpha = float(color.a);
    float3 c = float3(color.rgb) / alpha;
    float lum = dot(c, kLuma);

    // Точка в долях обложки, центр — ноль; d — поперёк полосы (с повтором), s — вдоль.
    float2 origin = bounds.xy + margin;
    float2 side = max(bounds.zw - 2.0 * margin, float2(1.0));
    float2 p = (position - origin) / side - 0.5;
    float2 q = p - (kRest + light);
    float d = dot(q, kNormal);
    d -= kPeriod * rint(d / kPeriod);
    float s = dot(q, kAlong);

    float along = exp(-s * s / (2.0 * kSigmaAlong * kSigmaAlong));
    float band = exp(-d * d / (2.0 * kSigmaBand * kSigmaBand)) * along;
    float core = exp(-d * d / (2.0 * kSigmaCore * kSigmaCore)) * along;
    float fringe = band * smoothstep(kFringeFrom, kFringeTo, abs(d));

    // Спектр — косинусная палитра с постоянной суммой каналов: тёмных порядков, как
    // у тонкой плёнки, в нём нет, и полоса не рвётся грязными провалами.
    float h = kHueAcross * d + kHueAlong * s + kHueInk * lum + kHueFlow * dot(light, kNormal) + hue;
    float3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (h + float3(0.0, 1.0 / 3.0, 2.0 / 3.0)));
    // Цвет без яркости: на чёрном светит, на белом тонирует, середину сдвигает по оттенку.
    float3 chroma = spectrum - dot(spectrum, kLuma);

    // 1. Белый свет — «экраном»: на чёрном виден, белое не выжигает, каналы широкой
    //    гаммы (> 1) не трогает. Общего клампа нет — P3-обложки не обрезаются.
    float white = amount * (kCore * core + kSheen * band);
    c += white * max(1.0 - c, 0.0);
    // 2. Перелив — по краям полосы и слабее по всему сиянию.
    float tint = amount * kChroma * mix(fringe, band, kChromaEverywhere);
    c += chroma * tint;

    // 3. Дизер ±½ уровня там, где эффект есть: мягкий глянец на тёмной гладкой обложке
    //    иначе ложится ступенями. Шум — по пикселям экрана, а не по пунктам; гаснет
    //    вместе с эффектом.
    float2 pixel = floor(position * scale);
    float noise = fract(52.9829189 * fract(dot(pixel, float2(0.06711056, 0.00583715)))) - 0.5;
    c += noise * min(1.0, (white + tint) * 8.0) / 255.0;

    return half4(half3(c * alpha), color.a);
}
