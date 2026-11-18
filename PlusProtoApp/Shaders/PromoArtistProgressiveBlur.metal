#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Figma artist_blur: 25 → 0 from upper left to (0.42949, 0.42628),
// plus the same effect rotated 180°. The full composited portrait is blurred.
[[ stitchable ]] half4 promoArtistProgressiveBlur(float2 position, SwiftUI::Layer layer,
                                                  float2 size, float2 axis) {
    float2 uv = position / size;
    const float2 start = float2(0.0064102565, 0.0032051282);
    const float2 end = float2(0.42948717, 0.42628205);
    float2 direction = end - start;
    float upperLeft = 1.0 - saturate(dot(uv - start, direction) / dot(direction, direction));
    float lowerRight = 1.0 - saturate(dot(1.0 - uv - start, direction) / dot(direction, direction));
    float radius = 25.0 * max(upperLeft, lowerRight);
    if (radius < 0.1) return layer.sample(position);
    half4 result = half4(0.0);
    float total = 0.0;
    for (int i = -8; i <= 8; ++i) {
        float t = float(i) / 8.0;
        float weight = exp(-2.0 * t * t);
        result += layer.sample(position + axis * t * radius) * half(weight);
        total += weight;
    }
    return result / half(total);
}
