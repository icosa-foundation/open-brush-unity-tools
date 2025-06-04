void DanceFloorVertex_float(
    float3 worldPos,
    float3 normalOS,
    float4 color,
    float lifetimeMod,
    float time,
    out float3 modifiedWorldPos,
    out float4 modifiedColor)
{
    float lifetime = time - lifetimeMod;

    // The mesh position is already quantized from the compute shader,
    // but we still need to apply the time-based animation effects
    // Apply normal-based displacement that changes over time
    modifiedWorldPos = worldPos + normalOS * pow(fmod(lifetime, 1), 3) * 0.1;

    // Color transformation
    color.xyz = pow(fmod(lifetime, 1), 3) * color.xyz;
    modifiedColor = 2 * color;
}
