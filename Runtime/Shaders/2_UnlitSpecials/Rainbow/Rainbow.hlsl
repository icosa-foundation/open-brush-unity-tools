#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/AudioReactive.hlsl"

// Audio-reactive halves, ported from Rainbow.shader's GetAudioReactiveRainbowColor /
// GetAudioReactiveColor. The first one's pulse line was commented out in the original; kept so.
float4 Rainbow_AR_Rainbow(float2 texcoord)
{
    texcoord = saturate(texcoord);
    float2 uvs = texcoord;
    float row_id = floor(uvs.y * 5);
    uvs.y *= 5;
    float4 tex = float4(0, 0, 0, 1);
    float row_y = fmod(uvs.y, 1);
    row_id = ceil(fmod(row_id + _BeatOutputAccum.x * 3, 5)) - 1;
    tex.rgb = row_id == 0 ? float3(1, 0, 0)    : tex.rgb;
    tex.rgb = row_id == 1 ? float3(.7, .3, 0)  : tex.rgb;
    tex.rgb = row_id == 2 ? float3(0, 1, .0)   : tex.rgb;
    tex.rgb = row_id == 3 ? float3(0, .2, 1)   : tex.rgb;
    tex.rgb = row_id == 4 ? float3(.4, 0, 1.2) : tex.rgb;
    tex.rgb *= saturate(pow(row_y * (1 - row_y) * 5, 50));
    return tex;
}

float4 Rainbow_AR_Color(float2 texcoord)
{
    texcoord = texcoord.yx;
    texcoord.y *= 2;
    float quantizedMotion = ceil((_BeatOutputAccum.z * .1) / 10);
    float row_id = abs(texcoord.y * 12 + quantizedMotion);
    float4 tex = float4(0, 0, 0, 1);
    float row_y = fmod(abs(row_id), 1.0);
    row_id = ceil(fmod(row_id, 8));
    float bandlevels = SampleFFTTex(row_id / 8).w;
    bandlevels = max(bandlevels, .1);
    tex.rgb = abs(texcoord.x - .5) < bandlevels * .5 ? float3(1, 1, 1) : tex.rgb;
    tex.rgb *= tex.rgb * .5 + tex.rgb * _BeatOutput.y;
    tex.rgb *= saturate(20 - abs(row_y - .5) * 50);
    return tex;
}

void rainbowFrag_float(float2 uv0, float4 vertexColor, float emissionGain, out float3 color)
{
    color = float3(0, 0, 0);

    vertexColor.a = 1;

#ifdef AUDIO_REACTIVE
    float4 tex = Rainbow_AR_Rainbow(uv0) * Rainbow_AR_Color(uv0);
    tex = vertexColor * tex * exp(emissionGain * 2.5f);
#else
    // Create parametric UV's
    float2 uvs = saturate(uv0);
    float row_id = floor(uvs.y * 5);
    uvs.y *= 5;

    // Create parametric colors
    float4 tex = float4(0,0,0,1);
    float4 row_y = fmod(uvs.y,1);

    row_id = ceil(fmod(row_id + GetBrushTime().z,5)) - 1;

    tex.rgb = row_id == 0 ? float3(1,0,0) : tex.rgb;
    tex.rgb = row_id == 1 ? float3(.7,.3,0) : tex.rgb;
    tex.rgb = row_id == 2 ? float3(0,1,.0) : tex.rgb;
    tex.rgb = row_id == 3 ? float3(0,.2,1) : tex.rgb;
    tex.rgb = row_id == 4 ? float3(.4,0,1.2) : tex.rgb;

    // Make rainbow lines pulse
    tex.rgb *= pow( (sin(row_id * 1 + GetBrushTime().z)   + 1)/2,5);

    // Make rainbow lines thin
    tex.rgb *= saturate(pow(row_y * (1 - row_y) * 5, 50));

    tex *= vertexColor * exp(emissionGain * 3.0f);
#endif

    color = tex.rgb * tex.a;
}

void rainbowFrag_half(half2 uv0, half4 vertexColor, half emissionGain, out half3 color)
{
    color = half3(0, 0, 0);

    vertexColor.a = 1;

#ifdef AUDIO_REACTIVE
    half4 tex = (half4)(Rainbow_AR_Rainbow(uv0) * Rainbow_AR_Color(uv0));
    tex = vertexColor * tex * exp(emissionGain * 2.5f);
#else
    // Create parametric UV's
    half2 uvs = saturate(uv0);
    half row_id = floor(uvs.y * 5);
    uvs.y *= 5;

    // Create parametric colors
    half4 tex = half4(0,0,0,1);
    half row_y = fmod(uvs.y,1);

    row_id = ceil(fmod(row_id + GetBrushTime().z,5)) - 1;

    tex.rgb = row_id == 0 ? half3(1,0,0) : tex.rgb;
    tex.rgb = row_id == 1 ? half3(.7,.3,0) : tex.rgb;
    tex.rgb = row_id == 2 ? half3(0,1,.0) : tex.rgb;
    tex.rgb = row_id == 3 ? half3(0,.2,1) : tex.rgb;
    tex.rgb = row_id == 4 ? half3(.4,0,1.2) : tex.rgb;

    // Make rainbow lines pulse
    tex.rgb *= pow( (sin(row_id * 1 + GetBrushTime().z)   + 1)/2,5);

    // Make rainbow lines thin
    tex.rgb *= saturate(pow(row_y * (1 - row_y) * 5, 50));

    tex *= vertexColor * exp(emissionGain * 3.0f);
#endif

    color = tex.rgb * tex.a;
}
