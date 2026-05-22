#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/AudioReactive.hlsl"

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

#ifdef AUDIO_REACTIVE
    // Audio path: beat-driven lifetime override (matches original; drives both displacement
    // and the color fade below). The original's extra waveform tint was dead code (overwritten),
    // so only the lifetime override and the _BeatOutput.x color term are reproduced.
    lifetime = lifetimeMod * 10 + _BeatOutputAccum.x;
#endif

    // The mesh position is already quantized from the compute shader,
    // but we still need to apply the time-based animation effects
    // Apply normal-based displacement that changes over time
    modifiedWorldPos = worldPos + normalOS * pow(fmod(lifetime, 1), 3) * 0.1;

    // Color transformation
    color.xyz = pow(fmod(lifetime, 1), 3) * color.xyz;
#ifdef AUDIO_REACTIVE
    modifiedColor = 2 * color + color.yzxw * _BeatOutput.x;
#else
    modifiedColor = 2 * color;
#endif
}
