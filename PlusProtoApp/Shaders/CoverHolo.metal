#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Рефлекс обложки (`CoverHolo.swift`). История: голография 2026-10-31 → «окно в комнате»
// 2026-11-04 → полоса за светом 2026-11-04 по итогам исследования (фидбек пользователя на
// устройстве: «не выглядит натурально; полоска рефлекса должна меняться от наклона, и её угол
// тоже»). Выводы исследования, на которых держится рецепт:
//  • свет закреплён в мире, вход — поза телефона относительно опоры по всем трём осям: поворот
//    в плоскости экрана поворачивает полосу 1:1, наклон двигает и поворачивает её (Telegram
//    Wallet, системный свет iOS 26, LookingGlassUI);
//  • одна яркая узкая полоса с длинным мягким ореолом, а не набор тусклых предметов — у тех
//    яркость уровня белой стены, и они читаются дымкой;
//  • складывать в линейном свете: «экран» в гамме молочно поднимает средние тона;
//  • перелив физичен только в отражённом свете (тонкая плёнка), радужных кромок нет.
// Варианты (`CoverSheenStyle`) — для сравнения на устройстве, разведены по характеру (первые три
// на устройстве читались одинаково): 0 — полоса за светом (медленная, прямая), 1 — кольцевая
// лампа (тонкая заметная дуга, скорость настоящего глянца), 2 — перламутр (широкий пастельный
// перелив), 3 — блик по кромке (лицо обложки чистое, как у Liquid Glass).
// Сила у всех — вдвое ниже первой сборки: «в целом надо снизить интенсивность/заметность блика»
// (правка пользователя 2026-11-04).
// Оси: экран — x вправо, y вниз (SwiftUI); свет — оси CoreMotion: x вправо, y вверх, z к глазу.
// При `amount = 0` пиксель возвращается как есть — вход и уход эффекта бесшовны.

namespace cover_sheen {
    // Полоса: ядро и ореол, гауссы в долях большей стороны обложки. Ядро FWHM ~0.09 — узкое,
    // ореол вчетверо шире: блик читается бликом на лаке, а не лучом света (ядро FWHM 0.14 на
    // первом кадре читалось лучом). Пики — в линейном свете (ядро 0.11 на чёрном — sRGB ~0.37).
    constant float kCoreSigma = 0.04;
    constant float kHaloSigma = 0.16;
    constant float kCore = 0.11;
    constant float kHalo = 0.022;
    // Вдоль полосы она ярче у середины и к концам гаснет до 70 % — конечная лампа, а не
    // наклейка от края до края.
    constant float kAlongSigma = 0.45;
    constant float kAlongFloor = 0.7;

    // Кольцевая лампа: глаз на оси в 3.5 сторонах, кольцо радиусом 24° — на обложке дуга
    // радиусом ~1.6 стороны, изгиб виден (при 55° дуга была почти прямой). Тонкая и чёткая:
    // ширины — углом.
    constant float kEye = 3.5;
    constant float kLampCoreSigma = 0.011;
    constant float kLampHaloSigma = 0.04;
    constant float kLampCore = 0.13;
    constant float kLampHalo = 0.02;

    // Перламутр — тонкая плёнка (n 1.38) окрашивает только отражённый свет. Толщина неровная —
    // 420 ± 140 нм пологими волнами по обложке: полоса, проходя, открывает то розовое, то
    // зеленоватое, а наклон ещё и сдвигает оттенок через угол падения; поперёк полосы оттенок
    // тоже идёт (2.5 рад угла на сторону). Полоса широкая и мягкая, почти без ядра, цвет
    // насыщеннее (пастель 28 % на светлых обложках терялась).
    constant float kFilmIndex = 1.38;
    constant float kFilmThickness = 420.0;
    constant float kFilmVariation = 140.0;
    constant float3 kWavelengths = float3(650.0, 532.0, 450.0);
    constant float kFilmAcross = 2.5;
    constant float kFilmSaturation = 0.7;
    constant float kPearlCoreSigma = 0.05;
    constant float kPearlHaloSigma = 0.2;
    constant float kPearlCore = 0.035;
    constant float kPearlHalo = 0.045;

    // Кромка ловит свет стороной к нему (и вдвое слабее противоположной — внутреннее отражение,
    // как у бликов Liquid Glass): полоса 1.2 pt внутрь от края по альфе слоя. В варианте «блик
    // по кромке» она — весь эффект: шире (2.4 pt) и ярче. Ширина не больше
    // `CoverHoloConfig.sampleReach` — дальше слой не отдаёт пиксели.
    constant float kRimWidth = 1.2;
    constant float kRim = 0.045;
    constant float kEdgeWidth = 2.4;
    constant float kEdge = 0.13;
    constant float kRimBack = 0.5;

    constant float3 kLuma = float3(0.2126, 0.7152, 0.0722);

    /// sRGB ↔ линейный, со знаком — каналы широкой гаммы (P3 в extended sRGB) не ломаются.
    static float3 toLinear(float3 c) {
        float3 a = abs(c);
        return sign(c) * select(pow((a + 0.055) / 1.055, 2.4), a / 12.92, a <= 0.04045);
    }

    static float3 toGamma(float3 c) {
        float3 a = abs(c);
        return sign(c) * select(1.055 * pow(a, 1.0 / 2.4) - 0.055, a * 12.92, a <= 0.0031308);
    }

    /// Ядро и ореол по расстоянию `d` от середины полосы.
    static float profile(float d, float core, float coreSigma, float halo, float haloSigma) {
        return core * exp(-d * d / (2.0 * coreSigma * coreSigma))
             + halo * exp(-d * d / (2.0 * haloSigma * haloSigma));
    }

    /// Толщина плёнки в точке `p`: три пологие некратные волны по обложке, ±1.
    static float filmWaves(float2 p) {
        return 0.5 * sin(6.2831853 * dot(p, float2(1.3, 0.7)) + 1.0)
             + 0.3 * sin(6.2831853 * dot(p, float2(-0.9, 1.7)) + 2.3)
             + 0.2 * sin(6.2831853 * dot(p, float2(2.3, -0.4)) + 4.1);
    }

    /// Цвет тонкой плёнки толщины `thickness` (нм) при угле падения `theta`, нормированный
    /// по яркости: интерференция двух отражений с разностью хода 2·n·d·cos θt.
    static float3 thinFilm(float theta, float thickness) {
        float sinT = sin(theta) / kFilmIndex;
        float cosT = sqrt(max(1.0 - sinT * sinT, 0.0));
        float3 phase = 6.2831853 * (2.0 * kFilmIndex * thickness * cosT) / kWavelengths;
        float3 color = 0.5 - 0.5 * cos(phase);
        // По среднему каналов, а не по яркости: иначе синий порядок раздувался бы в разы.
        return min(color / max((color.r + color.g + color.b) / 3.0, 1e-3), float3(2.0));
    }
}

/// `bounds` — кадр вью эффекта (`.boundingRect`), `margin` — прозрачное поле вокруг обложки.
/// `a`: полоса — (нормаль полосы на экране, к свету; точка её середины в долях стороны, центр
/// обложки — ноль, y вниз); лампа — (центр кольца в осях обложки; радиус кольца).
/// `b` — (направление на свет в осях обложки; сила от отклонения позы). `amount` — огибающая
/// × сила; `style` — вариант; `scale` — пикселей в пункте (дизер).
[[ stitchable ]] half4 coverHolo(float2 position, SwiftUI::Layer layer, float4 bounds, float margin,
                                 float4 a, float4 b, float amount, float style, float scale) {
    using namespace cover_sheen;
    half4 color = layer.sample(position);
    if (amount <= 0.0 || color.a <= 0.0h) {
        return color;
    }
    float strength = amount * b.w;

    // Цвет приходит с умноженной альфой — снимаем её, работаем в линейном свете.
    float alpha = float(color.a);
    float3 lin = toLinear(float3(color.rgb) / alpha);

    // Точка на обложке в долях большей стороны (у книги стороны разные), центр — ноль, y вниз.
    float2 origin = bounds.xy + margin;
    float2 size = max(bounds.zw - 2.0 * margin, float2(1.0));
    float2 p = (position - origin - 0.5 * size) / max(size.x, size.y);

    bool isEdge = style > 2.5;
    float3 light = float3(0.0);
    if (style < 0.5 || (style > 1.5 && !isEdge)) {
        // Полоса за светом и перламутр: поперёк направления на свет, середина — в точке `a.zw`.
        float2 normal = a.xy;
        float2 along = float2(-normal.y, normal.x);
        float2 offset = p - a.zw;
        float across = dot(offset, normal);
        float lengthwise = dot(offset, along);
        float fade = mix(kAlongFloor, 1.0, exp(-lengthwise * lengthwise / (2.0 * kAlongSigma * kAlongSigma)));
        if (style < 0.5) {
            light = float3(profile(across, kCore, kCoreSigma, kHalo, kHaloSigma) * fade);
        } else {
            // Перламутр: угол падения — от высоты света и поперёк полосы.
            float theta = acos(clamp(b.z, -1.0, 1.0)) + kFilmAcross * across;
            float thickness = kFilmThickness + kFilmVariation * filmWaves(p);
            float3 tint = mix(float3(1.0), thinFilm(theta, thickness), kFilmSaturation);
            light = profile(across, kPearlCore, kPearlCoreSigma, kPearlHalo, kPearlHaloSigma) * fade * tint;
        }
    } else if (!isEdge) {
        // Кольцевая лампа: попиксельное отражение, глаз на оси; расстояние до кольца — углом.
        float3 reflected = normalize(float3(p.x, -p.y, kEye));
        float distance = acos(clamp(dot(reflected, a.xyz), -1.0, 1.0)) - a.w;
        light = float3(profile(distance, kLampCore, kLampCoreSigma, kLampHalo, kLampHaloSigma));
    }

    // Кромка: где край (по альфе на трёх расстояниях в четыре стороны) и куда наружу; горит
    // сторона к свету. Внутри обложки — четыре выборки и мимо.
    float rimWidth = isEdge ? kEdgeWidth : kRimWidth;
    float2 rimX = float2(rimWidth, 0.0);
    float2 rimY = float2(0.0, rimWidth);
    float4 far = float4(layer.sample(position + rimX).a, layer.sample(position - rimX).a,
                        layer.sample(position + rimY).a, layer.sample(position - rimY).a);
    float farMin = min(min(far.x, far.y), min(far.z, far.w));
    float2 toLight = float2(b.x, -b.y);
    float lightSpread = length(toLight);
    if (farMin < 0.999 && lightSpread > 1e-3) {
        float2 midX = rimX * (2.0 / 3.0), midY = rimY * (2.0 / 3.0);
        float2 nearX = rimX / 3.0, nearY = rimY / 3.0;
        float4 mid = float4(layer.sample(position + midX).a, layer.sample(position - midX).a,
                            layer.sample(position + midY).a, layer.sample(position - midY).a);
        float4 near = float4(layer.sample(position + nearX).a, layer.sample(position - nearX).a,
                             layer.sample(position + nearY).a, layer.sample(position - nearY).a);
        float midMin = min(min(mid.x, mid.y), min(mid.z, mid.w));
        float nearMin = min(min(near.x, near.y), min(near.z, near.w));
        // Наружу — туда, где альфа падает: (−x минус +x, −y минус +y).
        float2 gradient = (far.yw - far.xz) + (mid.yw - mid.xz) + (near.yw - near.xz);
        float length2 = dot(gradient, gradient);
        if (length2 > 1e-6) {
            // Ступени 1/3, 2/3, 1 ширины, ближняя к краю — ярче всех: спад внутрь.
            float edge = 0.2 * (1.0 - farMin) + 0.3 * (1.0 - midMin) + 0.5 * (1.0 - nearMin);
            float facing = dot(gradient * rsqrt(length2), toLight / lightSpread);
            float lobes = pow(saturate(facing), 2.0) + kRimBack * pow(saturate(-facing), 2.0);
            // У света почти в лоб направления нет — кромка гаснет.
            light += (isEdge ? kEdge : kRim) * edge * lobes * smoothstep(0.08, 0.3, lightSpread);
        }
    }

    // Сложение в линейном свете с мягким потолком: на чёрном — чистый свет, белое не выжигает,
    // каналы широкой гаммы (> 1) не трогает.
    float3 added = light * strength;
    lin += added * max(1.0 - lin, 0.0);
    float3 c = toGamma(lin);

    // Дизер ±½ уровня там, где есть свет: мягкий ореол на тёмной обложке иначе ложится
    // ступенями. Шум — по пикселям экрана.
    float2 pixel = floor(position * scale);
    float noise = fract(52.9829189 * fract(dot(pixel, float2(0.06711056, 0.00583715)))) - 0.5;
    c += noise * min(1.0, dot(added, kLuma) * 40.0) / 255.0;

    return half4(half3(c * alpha), color.a);
}
