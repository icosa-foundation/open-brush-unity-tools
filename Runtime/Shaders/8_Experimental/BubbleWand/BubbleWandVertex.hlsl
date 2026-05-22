// Curl noise functions for displacement
float curlX(float3 p, float d) {
    return (
        (sin(p.y + d) - sin(p.y - d)) * (sin(p.z + d) + sin(p.z - d)) -
        (sin(p.z + d) - sin(p.z - d)) * (sin(p.y + d) + sin(p.y - d))
    ) / (4.0 * d * d);
}

float curlY(float3 p, float d) {
    return (
        (sin(p.z + d) - sin(p.z - d)) * (sin(p.x + d) + sin(p.x - d)) -
        (sin(p.x + d) - sin(p.x - d)) * (sin(p.z + d) + sin(p.z - d))
    ) / (4.0 * d * d);
}

float curlZ(float3 p, float d) {
    return (
        (sin(p.x + d) - sin(p.x - d)) * (sin(p.y + d) + sin(p.y - d)) -
        (sin(p.y + d) - sin(p.y - d)) * (sin(p.x + d) + sin(p.x - d))
    ) / (4.0 * d * d);
}

// The initial "bulge" displacement (radius * Normal * sin(uv0.x * PI)) is shared with
// bakeBubbleWand.compute. When a sketch is exported, that compute shader pre-applies the
// bulge to the vertex positions, drops uv0.z (glTF UV0 is only 2D), and preserves the
// radius in uv1.x. The _ISBAKEDEXPORT keyword tells us which of those two meshes we have:
//
//   not set -> raw mesh: the bulge has NOT been applied, and the radius is still in uv0.z.
//   set     -> baked mesh: the bulge IS already in Position, and the radius is now uv1.x.
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
    // Bulge displacement, computed identically to the bake compute.
    float wave = sin(UV0.x * 3.14159);
#ifdef _ISBAKEDEXPORT
    float radius = UV1.x; // baked: uv0.z was relocated here on export
#else
    float radius = UV0.z; // raw: radius still lives in uv0.z
#endif
    float3 wave_displacement = radius * Normal * wave;

    float3 pos = Position;
#ifndef _ISBAKEDEXPORT
    // Raw mesh: the bulge is not in the vertex positions yet, so apply it here.
    pos += wave_displacement;
#endif
    // Baked mesh: Position already includes the bulge from bakeBubbleWand.compute, so we
    // leave it alone and only layer the animated displacement below on top of it.

    // Scroll jitter displacement (animated, never baked)
    float t = Time * ScrollRate;
    pos.x += sin(t + Time + pos.z * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;
    pos.z += cos(t + Time + pos.x * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;
    pos.y += cos(t * 1.2 + Time + pos.x * ScrollJitterFrequency) * ScrollJitterIntensity * 0.1;

    // Curl noise displacement (animated, never baked)
    float d = 30;
    float freq = 0.1;
    float3 p = pos * freq + Time;
    float3 curl_displacement = float3(
        curlX(p, d),
        curlY(p, d),
        curlZ(p, d)
    ) * ScrollJitterIntensity * 0.1; // kDecimetersToWorldUnits constant

    // Final position
    DisplacedPosition = pos + curl_displacement;

    // Perturb normal based on both wave and curl displacement. The normal is not baked, so
    // this always runs; wave_displacement is recomputed above in both paths for this.
    DisplacedNormal = normalize(Normal + curl_displacement * 2.5 + wave_displacement * 2.5);
}
