#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/AudioReactive.hlsl"
void hypercolorAnim_float(float4 albedo, float2 uv, out float4 color)
{
    color = albedo;
    float scroll = GetBrushTime().z;

#ifdef AUDIO_REACTIVE
    // Fragment audio path from the original Hypercolor shader. The original used
    // local world position for this phase term; this graph only exposes UV here.
    float t = uv.x;
    scroll = _BeatOutputAccum.y * 30;

    color.rgb =  float3(1,0,0) * (sin(color.r * 2 + scroll*0.5 - t) + 1);
    color.rgb += float3(0,1,0) * (sin(color.r * 3 + scroll*1 - t) + 1);
    color.rgb += float3(0,0,1) * (sin(color.r * 4 + scroll*0.25 - t) + 1);
#else
    color.rgb =  float3(1,0,0) * (sin(color.r * 2 + scroll*0.5 - uv.x) + 1) * 2;
    color.rgb += float3(0,1,0) * (sin(color.r * 3.3 + scroll*1 - uv.x) + 1) * 2;
    color.rgb += float3(0,0,1) * (sin(color.r * 4.66 + scroll*0.25 - uv.x) + 1) * 2;
#endif
}

void hypercolorAnim_half(half4 albedo, half2 uv, out half4 color)
{
    color = albedo;
    half scroll = GetBrushTime().z;

#ifdef AUDIO_REACTIVE
    half t = uv.x;
    scroll = (half)(_BeatOutputAccum.y * 30);

    color.rgb =  half3(1,0,0) * (sin(color.r * 2 + scroll*0.5 - t) + 1);
    color.rgb += half3(0,1,0) * (sin(color.r * 3 + scroll*1 - t) + 1);
    color.rgb += half3(0,0,1) * (sin(color.r * 4 + scroll*0.25 - t) + 1);
#else
    color.rgb =  half3(1,0,0) * (sin(color.r * 2 + scroll*0.5 - uv.x) + 1) * 2;
    color.rgb += half3(0,1,0) * (sin(color.r * 3.3 + scroll*1 - uv.x) + 1) * 2;
    color.rgb += half3(0,0,1) * (sin(color.r * 4.66 + scroll*0.25 - uv.x) + 1) * 2;
#endif
}
