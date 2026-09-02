#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/8_Experimental/BubbleWand/BubbleWandNoise.hlsl"

// Preserve the package's previous curl approximation for exported glTF meshes. The
// original Tilt shader uses the noise implementation included above instead.
float BubbleWandExportCurlX(float3 p, float d) {
    return (
        (sin(p.y + d) - sin(p.y - d)) * (sin(p.z + d) + sin(p.z - d)) -
        (sin(p.z + d) - sin(p.z - d)) * (sin(p.y + d) + sin(p.y - d))
    ) / (4.0 * d * d);
}

float BubbleWandExportCurlY(float3 p, float d) {
    return (
        (sin(p.z + d) - sin(p.z - d)) * (sin(p.x + d) + sin(p.x - d)) -
        (sin(p.x + d) - sin(p.x - d)) * (sin(p.z + d) + sin(p.z - d))
    ) / (4.0 * d * d);
}

float BubbleWandExportCurlZ(float3 p, float d) {
    return (
        (sin(p.x + d) - sin(p.x - d)) * (sin(p.y + d) + sin(p.y - d)) -
        (sin(p.y + d) - sin(p.y - d)) * (sin(p.x + d) + sin(p.x - d))
    ) / (4.0 * d * d);
}

// The initial "bulge" displacement (radius * Normal * sin(uv0.x * PI)) is shared with
// bakeBubbleWand.compute. When a sketch is exported, that compute shader pre-applies the
// bulge to the vertex positions, drops uv0.z (glTF UV0 is only 2D), and preserves the
// radius in uv1.x. The two source keywords distinguish all three supported layouts:
//
//   _IS_TILT_MESH   -> live or .tilt geometry using the original Tilt vertex layout.
//   neither keyword -> legacy glTF behavior from the existing package shader.
//   _ISBAKEDEXPORT  -> BrushBaker output with the bulge in Position and radius in uv1.x.
//
// Either way the scroll jitter and curl noise are time-based and are never baked, so they
// must run in both paths. uv0.x (the parametric coordinate along the stroke) is part of
// the 2D UV0 and survives export, so the wave term is valid in both paths.
//
// Argument order matches the Custom Function node slots: the UV0 input is wired last
// (after ScrollJitterFrequency) because it was added after the original slots.
void BubbleWandVertex_float(
    float3 Position,
    float3 Normal,
    float4 UV0,
    float4 UV1,
    float Time,
    float ScrollRate,
    float ScrollJitterIntensity,
    float ScrollJitterFrequency,
    out float3 DisplacedPosition,
    out float3 DisplacedNormal)
{
    // Bulge displacement, computed identically to the bake compute and old Tilt shader.
    float wave = sin(UV0.x * 3.14159);
#ifdef _ISBAKEDEXPORT
    float radius = UV1.x;
#else
    float radius = UV0.z;
#endif
    float3 wave_displacement = radius * Normal * wave;

    float3 pos = Position;
#ifndef _ISBAKEDEXPORT
    pos += wave_displacement;
#endif

#ifdef _IS_TILT_MESH
    // The legacy shader uses scroll jitter only to choose where it samples curl noise.
    // It does not apply the jitter itself as a vertex displacement.
    float3 displacementSamplePosition = pos;
    float t = Time * ScrollRate;
    displacementSamplePosition.x +=
        sin(t + Time + displacementSamplePosition.z * ScrollJitterFrequency) *
        ScrollJitterIntensity;
    displacementSamplePosition.z +=
        cos(t + Time + displacementSamplePosition.x * ScrollJitterFrequency) *
        ScrollJitterIntensity;
    displacementSamplePosition.y +=
        cos(t * 1.2 + Time + displacementSamplePosition.x * ScrollJitterFrequency) *
        ScrollJitterIntensity;

    // Curl noise displacement (animated, never baked). The old shader uses
    // GetTime().x here; BrushTime supplies GetTime().y, which is 20x larger.
    float d = 30;
    float freq = 0.1;
    float curlTime = Time * 0.05;
    float3 p = displacementSamplePosition * freq + curlTime;
    float3 curl_displacement = float3(
        curlX(p, d),
        curlY(p, d),
        curlZ(p, d)
    ) * ScrollJitterIntensity * 0.1; // kDecimetersToWorldUnits constant
#else
    // Preserve the package's pre-parity behavior for both exported glTF layouts.
    float t = Time * ScrollRate;
    pos.x += sin(t + Time + pos.z * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;
    pos.z += cos(t + Time + pos.x * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;
    pos.y += cos(t * 1.2 + Time + pos.x * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;

    float d = 30;
    float freq = 0.1;
    float3 p = pos * freq + Time;
    float3 curl_displacement = float3(
        BubbleWandExportCurlX(p, d),
        BubbleWandExportCurlY(p, d),
        BubbleWandExportCurlZ(p, d)
    ) * ScrollJitterIntensity * 0.1;
#endif

    // Final position
    DisplacedPosition = pos + curl_displacement;

    // Perturb normal based on both wave and curl displacement. The normal is not baked, so
    // this always runs; wave_displacement is recomputed above in both paths for this.
    DisplacedNormal = normalize(Normal + curl_displacement * 2.5 + wave_displacement * 2.5);
}
