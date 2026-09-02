void KeijiroTubeVertex_float(
    float2 uv,
    float radius,
    float time,
    float3 posIn,
    float3 normal,
    out float3 posOut)
{
#ifdef _IS_TILT_MESH
    float wave = sin(uv.x - time * 2);
    float pulse = smoothstep(.45, .5, saturate(wave));
    posOut = posIn - pulse * radius * normal;
#else
    // Exported meshes do not expose the Tilt radius in uv0.z. New exports already
    // contain the contraction; legacy exports retain the package's fragment fallback.
    posOut = posIn;
#endif
}

void KeijiroTubeFragment_float(
    float2 uv,
    float time,
    out float alpha)
{
#ifdef _IS_TILT_MESH
    alpha = 1.0;
#elif defined(_ISBAKEDEXPORT)
    // BrushBaker already applied the contraction to the exported positions.
    alpha = 1.0;
#else
    // Preserve the package's previous fallback for legacy glTF meshes.
    float wave = sin(uv.x - time * 2);
    alpha = smoothstep(.45, .5, saturate(wave));
#endif
}
