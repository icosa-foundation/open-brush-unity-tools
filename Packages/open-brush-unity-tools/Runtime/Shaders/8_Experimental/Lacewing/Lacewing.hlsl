
#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/AudioReactive.hlsl"

void LacewingFragment_float(
    float4 spectex,
    float2 specuv,
    float4 tex,
    float scroll,
    float4 vertexColor,
    float4 specTint,
    out float3 color,
    out float3 specColor,
    out float alpha) {

#ifdef AUDIO_REACTIVE
    // Fragment audio path from the original Lacewing shader. The original used
    // local world position for this phase term; this graph only exposes UV here.
    float t = specuv.x;
    scroll = _BeatOutputAccum.y * 30;

    spectex.rgb = float3(1, 0, 0) * (sin(spectex.r * 2 + scroll * 0.5 - t) + 1);
    spectex.rgb += float3(0, 1, 0) * (sin(spectex.r * 3 + scroll * 1 - t) + 1);
    spectex.rgb += float3(0, 0, 1) * (sin(spectex.r * 4 + scroll * 0.25 - t) + 1);
#else
    spectex.rgb = float3(1, 0, 0) * (sin(spectex.r * 2 + scroll * 0.5 - specuv.x) + 1) * 1;
    spectex.rgb += float3(0, 1, 0) * (sin(spectex.r * 3.3 + scroll * 1 - specuv.x) + 1) * 1;
    spectex.rgb += float3(0, 0, 1) * (sin(spectex.r * 4.66 + scroll * 0.25 - specuv.x) + 1) * 1;
#endif

    color = (tex * vertexColor).rgb;
    specColor = (specTint * spectex).rgb;
#ifdef AUDIO_REACTIVE
    specColor *= 0.5;
#endif
    alpha = tex.a * vertexColor.a;
}
