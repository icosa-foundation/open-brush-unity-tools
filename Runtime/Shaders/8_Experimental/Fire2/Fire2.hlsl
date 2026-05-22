#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/AudioReactive.hlsl"

float4 bloomColor(float4 color, float emissionGain)
{
    float3 emission = color.rgb * color.rgb * emissionGain;
    return float4(color.rgb + emission, color.a);
}

void Fire2Fragment_float(
    UnityTexture2D mainTex,
    UnityTexture2D displaceTex,
    float2 uv,
    float displacementIntensity,
    float4 vertexColor,
    float scroll1,
    float scroll2,
    float flameFadeMin,
    float emissionGain,
    float time,
    out float3 finalColor,
    out float finalOpacity
)
{
    time = time / 20.0;
    half2 displacement = tex2D(displaceTex, uv).xy;
    displacement = displacement * 2.0 - 1.0;
    displacement *= displacementIntensity;

    half mask = tex2D(mainTex, uv).y;

    uv += displacement;

    half flame1 = tex2D(mainTex, uv * 0.7 + half2(-time * scroll1, 0)).x;
    half flame2 = tex2D(mainTex, half2(uv.x, 1.0-uv.y) + half2(-time * scroll2, -time * scroll2 / 4)).x;

    half flames = saturate(flame1 + flame2) / 2.0;
    flames = smoothstep(0, 0.8, mask * flames);
    flames *= mask;

    half4 tex = half4(flames, flames, flames, 1.0);
    float flameFade = flameFadeMin;
#ifdef AUDIO_REACTIVE
    // Original Fire2 lerped _FlameFadeMin.._FlameFadeMax by 1 - _BeatOutput.w.
    // The ported graph only exposes the min value, so use the original max default.
    flameFade = lerp(flameFadeMin, 30.0, 1.0 - saturate(_BeatOutput.w));
#endif
    tex.xyz *= pow(1.0 - uv.x, flameFade) * (flameFade * 2);

    vertexColor = bloomColor(vertexColor, emissionGain);
    float4 col = vertexColor * tex;
    finalColor = float3(col.rgb * col.a);
    finalOpacity = col.a;
}
