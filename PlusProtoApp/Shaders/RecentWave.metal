#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Texture-based deformation preserves the original palette and contour.
// At time zero sampling is exactly the identity transform.
[[ stitchable ]] half4 recentWaveFlow(float2 position, SwiftUI::Layer layer,
                                     float2 size, float time, float amplitude,
                                     float coreSpeed, float middleSpeed, float rimSpeed) {
    if (time <= 0.0) { return layer.sample(position); }
    float2 center = size * 0.5;
    float2 p = position - center;
    float angle = atan2(p.y, p.x);
    float radius = length(p / max(size, float2(1.0)));
    float edge = smoothstep(0.04, 0.28, radius);
    // Four times slower flow. Each soft region rotates independently; sampling
    // three layers avoids indefinitely stretching the texture between regions.
    float phase = time * 0.25;
    float wave = 0.65 * sin(phase * 1.6) * sin(3.0 * angle + phase * 0.6)
               + 0.35 * sin(phase * 0.9) * cos(5.0 * angle - phase * 1.2);
    float dilation = 1.0 + amplitude * 2.0 * edge * wave;
    float flow = amplitude * 2.0 * edge * sin(phase * 0.8);
    float3 turns = -time * 0.12 * float3(coreSpeed, middleSpeed, rimSpeed) + flow;
    float3 c = cos(turns), s = sin(turns);
    half4 core = layer.sample(float2(c.x * p.x - s.x * p.y, s.x * p.x + c.x * p.y) / dilation + center);
    half4 middle = layer.sample(float2(c.y * p.x - s.y * p.y, s.y * p.x + c.y * p.y) / dilation + center);
    half4 rim = layer.sample(float2(c.z * p.x - s.z * p.y, s.z * p.x + c.z * p.y) / dilation + center);
    float coreWeight = 1.0 - smoothstep(0.10, 0.26, radius);
    float rimWeight = smoothstep(0.30, 0.48, radius);
    float middleWeight = 1.0 - coreWeight - rimWeight;
    return core * half(coreWeight) + middle * half(middleWeight) + rim * half(rimWeight);
}
