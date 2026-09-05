#ifndef OPENBRUSH_AUDIO_REACTIVE_INCLUDED
#define OPENBRUSH_AUDIO_REACTIVE_INCLUDED

#include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/0_Subgraphs/BrushTime.hlsl"

// --------------------------------------------------------------------------------------------
// Audio-reactive globals.
//
// These are set every frame by Open Brush's VisualizerManager via Shader.SetGlobalTexture /
// Shader.SetGlobalVector. This package does NOT set them, so when used standalone they default
// to zero (vectors) / an unbound texture (samples ~0) and all reactive effects fall back to a
// static result. See AUDIO_REACTIVE_PORTING.md for details.
//
// Channel layout:
//   _WaveFormTex   : r=waveform  g=smoothed         b=low-pass               a=high-pass
//   _FFTTex        : r=FFT        g=FFT power curve  b=peak FFT power curve   a=normalized bands
//   _BeatOutput    : per-band instantaneous beat  (x=reaktor y=alt z=low-pass w=high-pass)
//   _BeatOutputAccum: per-band accumulated beat    (same band order; the scroll / time driver)
//   _PeakBandLevels: x=band0 y=band1 z=band2 w=band3
// --------------------------------------------------------------------------------------------

sampler2D _WaveFormTex;
sampler2D _FFTTex;
float4 _BeatOutput;
float4 _BeatOutputAccum;
float4 _PeakBandLevels;
float4 _AudioVolume;


// LOD sampling (mip 0) so these are safe in both the vertex and fragment stages.
float4 SampleWaveformTex(float coord) { return tex2Dlod(_WaveFormTex, float4(coord, 0, 0, 0)); }
float4 SampleFFTTex(float coord)      { return tex2Dlod(_FFTTex,      float4(coord, 0, 0, 0)); }

// --------------------------------------------------------------------------------------------
// Shared "musicReactive" helpers, ported from Assets/Shaders/Include/Brush.cginc.
// GetTime().w in the original is replaced with GetBrushTime().w (respects time override).
// --------------------------------------------------------------------------------------------

float OB_RandomizeByColor(float4 color)
{
    // NB: don't declare a local `PI` — URP's Common.hlsl already defines it as a macro.
    float val = (3 * color.r + 2 * color.g + color.b) * 1000;
    val = 2 * 3.14159265359 * fmod(val, 1);
    return val;
}

float3 OB_RandomNormal(float3 color)
{
    float noiseX = frac(sin(color.x)) * 46336.23745f;
    float noiseY = frac(sin(color.y)) * 34748.34744f;
    float noiseZ = frac(sin(color.z)) * 59998.47362f;
    return normalize(float3(noiseX, noiseY, noiseZ));
}

// Per-band beat brightness pulse.
float4 OB_MusicReactiveColor(float4 color, float beat)
{
    float randomOffset = OB_RandomizeByColor(color);
    color.xyz = color.xyz * .5 + color.xyz * saturate(sin(beat * 3.14159 + randomOffset));
    return color;
}

// Plucked-string vertex vibration along the stroke. Operates in world space; the first sin term
// pins the stroke's start/end (t in 0:1) to zero modulation, the second vibrates along it.
float3 OB_MusicReactiveAnimationWS(float3 positionWS, float4 color, float beat, float t)
{
    float intensity = .15;
    float randomOffset = 2 * 3.14159 * OB_RandomizeByColor(color) + GetBrushTime().w + positionWS.z;
    positionWS += OB_RandomNormal(color.rgb) * beat * sin(t * 3.14159) * sin(randomOffset) * intensity;
    return positionWS;
}

// --------------------------------------------------------------------------------------------
// Shader Graph custom-function entry points (_float / _half variants).
// --------------------------------------------------------------------------------------------

void AudioBands_float(out float4 beat, out float4 beatAccum, out float4 peakBands)
{
    beat = _BeatOutput;
    beatAccum = _BeatOutputAccum;
    peakBands = _PeakBandLevels;
}
void AudioBands_half(out half4 beat, out half4 beatAccum, out half4 peakBands)
{
    beat = (half4)_BeatOutput;
    beatAccum = (half4)_BeatOutputAccum;
    peakBands = (half4)_PeakBandLevels;
}

void SampleWaveform_float(float coord, out float4 waveform)
{
    waveform = SampleWaveformTex(coord);
}
void SampleWaveform_half(float coord, out half4 waveform)
{
    waveform = (half4)SampleWaveformTex(coord);
}

void SampleFFT_float(float coord, out float4 fft)
{
    fft = SampleFFTTex(coord);
}
void SampleFFT_half(float coord, out half4 fft)
{
    fft = (half4)SampleFFTTex(coord);
}

// Drop-in BaseColor intercept for brushes that are pure node graphs (no per-brush .hlsl):
// applies the beat brightness pulse when AUDIO_REACTIVE is on, passes color through unchanged
// when off. `band` selects the _BeatOutput channel (0=x, 1=y, 2=z, 3=w). Used by the Group A
// node-injection script.
void MusicReactiveColorBand_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = OB_MusicReactiveColor(float4(colorIn, 1), beat).rgb;
#else
    colorOut = colorIn;

#endif
}
void MusicReactiveColorBand_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = (half3)OB_MusicReactiveColor(float4((float3)colorIn, 1), beat).rgb;
#else
    colorOut = colorIn;
#endif
}

// Beat brightness boost: colorOut = colorIn * (1 + _BeatOutput[band]). Matches the common
// `tex += tex * _BeatOutput.x` pattern (Streamers etc.). Gated; passthrough when off.
void BeatColorBoost_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (1 + beat);
#else
    colorOut = colorIn;
#endif
}
void BeatColorBoost_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (1 + beat);
#else
    colorOut = colorIn;
#endif
}

// Embers beat colour: colorOut = colorIn * (0.5 + 2 * _BeatOutput[band]). Matches the original
// `v.color.rgb = v.color.rgb*.5 + 2*_BeatOutput.x*v.color.rgb`. Gated; passthrough when off.
void EmbersBeatColor_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.5 + 2 * beat);
#else
    colorOut = colorIn;
#endif
}
void EmbersBeatColor_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.5 + 2 * beat);
#else
    colorOut = colorIn;
#endif
}

// LightWire beat colour: colorOut = colorIn * (0.25 + 0.75 * _BeatOutput[band]).
// Matches the original `IN.color.rgb = IN.color.rgb * .25 + IN.color.rgb * _BeatOutput.x * .75`.
void LightWireBeatColor_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.25 + 0.75 * beat);
#else
    colorOut = colorIn;
#endif
}
void LightWireBeatColor_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.25 + 0.75 * beat);
#else
    colorOut = colorIn;
#endif
}

float3 LightWireLegacyEmission(float3 color, float4 uv, float on)
{
    float envelope = sin(fmod(uv.x * 2.0, 1.0) * 3.14159);
    if (envelope >= 0.1) return 0.0;

    int colorIndex = (int)fmod(uv.x * 2.0 + 0.5, 3.0);
    float3 tint = colorIndex == 0 ? float3(0.2, 0.2, 1.0)
                : colorIndex == 1 ? float3(1.0, 0.2, 0.2)
                                  : float3(0.2, 1.0, 0.2);
    color *= tint * on;
    float cmin = length(color) * 0.05;
    color = max(color, cmin.xxx);
    color = pow(max(color, 0.0), 2.2);
    return color * (2.0 * exp(0.7 * 10.0));
}

void LightWireChase_float(float3 colorIn, float4 uv, out float3 colorOut)
{
    float t;
#ifdef AUDIO_REACTIVE
    t = _BeatOutputAccum.x * 10;
#else
    t = GetBrushTime().w;
#endif
    float lightIndex = fmod(uv.x * 2 + 0.5, 7);
    float timeIndex = fmod(t, 7);
    float delta = abs(lightIndex - timeIndex);
    float on = 1 - saturate(delta * 1.5);
    colorOut = LightWireLegacyEmission(colorIn, uv, on);
}
void LightWireChase_half(half3 colorIn, half4 uv, out half3 colorOut)
{
    float t;
#ifdef AUDIO_REACTIVE
    t = _BeatOutputAccum.x * 10;
#else
    t = GetBrushTime().w;
#endif
    float lightIndex = fmod(uv.x * 2 + 0.5, 7);
    float timeIndex = fmod(t, 7);
    float delta = abs(lightIndex - timeIndex);
    float on = 1 - saturate(delta * 1.5);
    colorOut = (half3)LightWireLegacyEmission((float3)colorIn, (float4)uv, on);
}

// HyperGrid / DanceFloor colour pattern: 2 * color + color.yzx * _BeatOutput[band].
void YzxBeatColor_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = 2 * colorIn + colorIn.yzx * beat;
#else
    colorOut = colorIn;
#endif
}
void YzxBeatColor_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = 2 * colorIn + colorIn.yzx * beat;
#else
    colorOut = colorIn;
#endif
}

// NeonPulse emission pulse: original applies both audioMultiplier *= (1 + _BeatOutput.x)
// and IN.color += IN.color * _BeatOutput.w * .25 before bloom/neon emission.
void QuarterBeatColor_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (1 + _BeatOutput.x) * (1 + 0.25 * beat);
#else
    colorOut = colorIn;
#endif
}
void QuarterBeatColor_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (1 + _BeatOutput.x) * (1 + 0.25 * beat);
#else
    colorOut = colorIn;
#endif
}

// Stars beat brightness: brightness = brightness * (0.25 + 2 * _BeatOutput[band]).
void StarsBeatBrightness_float(float3 colorIn, float band, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.25 + 2 * beat);
#else
    colorOut = colorIn;
#endif
}
void StarsBeatBrightness_half(half3 colorIn, half band, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    colorOut = colorIn * (0.25 + 2 * beat);
#else
    colorOut = colorIn;
#endif
}

void StarsSparkleTime_float(float timeY, out float sparkleTime)
{
#ifdef AUDIO_REACTIVE
    sparkleTime = _BeatOutputAccum.w;
#else
    sparkleTime = timeY;
#endif
}
void StarsSparkleTime_half(half timeY, out half sparkleTime)
{
#ifdef AUDIO_REACTIVE
    sparkleTime = _BeatOutputAccum.w;
#else
    sparkleTime = timeY;
#endif
}

// The original Brush/Visualizer/WaveformPulse shader scrolled by GetTime().x * 15,
// and GetTime().x is _Time.x == t/20. The graph feeds this node BrushTime's Time
// output, which is _Time.y == t (seconds), so the scale here is 15/20 = 0.75.
// Feeding seconds through the old * 15.0 ran the pulse 20x too fast.
void NeonPulseScroll_float(float timeSeconds, out float scroll)
{
#ifdef AUDIO_REACTIVE
    scroll = _BeatOutputAccum.z;
#else
    scroll = timeSeconds * 0.75;
#endif
}
void NeonPulseScroll_half(half timeSeconds, out half scroll)
{
#ifdef AUDIO_REACTIVE
    scroll = _BeatOutputAccum.z;
#else
    scroll = timeSeconds * 0.75h;
#endif
}

void ElectricityAudioPosition_float(float3 positionOS, float4 uv, out float3 outPositionOS)
{
    outPositionOS = positionOS;
#ifdef AUDIO_REACTIVE
    float waveform = SampleWaveformTex(uv.x).r - 0.5;
    outPositionOS.y += waveform * 0.1;
#endif
}
void ElectricityAudioPosition_half(half3 positionOS, half4 uv, out half3 outPositionOS)
{
    outPositionOS = positionOS;
#ifdef AUDIO_REACTIVE
    half waveform = (half)(SampleWaveformTex(uv.x).r - 0.5);
    outPositionOS.y += waveform * 0.1h;
#endif
}

void ElectricityAudioColor_float(float3 colorIn, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    colorOut = colorIn * (0.5 + _BeatOutput.z * 0.5);
#else
    colorOut = colorIn;
#endif
}
void ElectricityAudioColor_half(half3 colorIn, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    colorOut = colorIn * (0.5h + (half)_BeatOutput.z * 0.5h);
#else
    colorOut = colorIn;
#endif
}

void HypercolorFamilyAudioPositionWithDirection_float(float3 positionOS, float3 displacementOS, float4 uv, out float3 outPositionOS)
{
    outPositionOS = positionOS;
#ifdef AUDIO_REACTIVE
    float strokeWidth = abs(uv.z) * 1.2;
    float t = _BeatOutputAccum.z * 5.0;
    float waveIntensity = _BeatOutput.z * 0.1 * strokeWidth;
    float wave = pow(1.0 - (sin(t + uv.x * 5.0 + uv.y * 10.0) + 1.0), 2.0);
    outPositionOS += wave * displacementOS * waveIntensity;
#endif
}

void HypercolorFamilyAudioPosition_float(float3 positionOS, float3 normalOS, float4 uv, out float3 outPositionOS)
{
    HypercolorFamilyAudioPositionWithDirection_float(positionOS, normalOS, uv, outPositionOS);
}

void HypercolorFamilyAudioPosition_float(float3 positionOS, float3 normalOS, float3 tangentOS, float4 uv, out float3 outPositionOS)
{
    HypercolorFamilyAudioPositionWithDirection_float(positionOS, cross(tangentOS, normalOS), uv, outPositionOS);
}

void HypercolorFamilyAudioPositionWithDirection_half(half3 positionOS, half3 displacementOS, half4 uv, out half3 outPositionOS)
{
    outPositionOS = positionOS;
#ifdef AUDIO_REACTIVE
    half strokeWidth = abs(uv.z) * 1.2h;
    half t = (half)(_BeatOutputAccum.z * 5.0);
    half waveIntensity = (half)_BeatOutput.z * 0.1h * strokeWidth;
    half wave = pow(1.0h - (sin(t + uv.x * 5.0h + uv.y * 10.0h) + 1.0h), 2.0h);
    outPositionOS += wave * displacementOS * waveIntensity;
#endif
}

void HypercolorFamilyAudioPosition_half(half3 positionOS, half3 normalOS, half4 uv, out half3 outPositionOS)
{
    HypercolorFamilyAudioPositionWithDirection_half(positionOS, normalOS, uv, outPositionOS);
}

void HypercolorFamilyAudioPosition_half(half3 positionOS, half3 normalOS, half3 tangentOS, half4 uv, out half3 outPositionOS)
{
    HypercolorFamilyAudioPositionWithDirection_half(positionOS, cross(tangentOS, normalOS), uv, outPositionOS);
}

void HypercolorFamilyAudioSurface_float(float3 baseColorIn, float3 specularIn, out float3 baseColorOut, out float3 emissionOut, out float3 specularOut)
{
#ifdef AUDIO_REACTIVE
    emissionOut = baseColorIn;
    baseColorOut = 0.2;
    specularOut = specularIn * 0.5;
#else
    baseColorOut = baseColorIn;
    emissionOut = 0;
    specularOut = specularIn;
#endif
}
void HypercolorFamilyAudioSurface_half(half3 baseColorIn, half3 specularIn, out half3 baseColorOut, out half3 emissionOut, out half3 specularOut)
{
#ifdef AUDIO_REACTIVE
    emissionOut = baseColorIn;
    baseColorOut = 0.2h;
    specularOut = specularIn * 0.5h;
#else
    baseColorOut = baseColorIn;
    emissionOut = 0;
    specularOut = specularIn;
#endif
}

// WigglyGraphite frame-step animation. Matches the original brush shader's audio branch:
// ceil(fmod(time.y * 3 + _BeatOutput.x * 3, 6)); otherwise ceil(fmod(time.y * 12, 6)).
void WigglyGraphiteAnim_float(float timeY, out float anim)
{
#ifdef AUDIO_REACTIVE
    anim = ceil(fmod(timeY * 3.0 + _BeatOutput.x * 3.0, 6.0));
#else
    anim = ceil(fmod(timeY * 12.0, 6.0));
#endif
}
void WigglyGraphiteAnim_half(half timeY, out half anim)
{
#ifdef AUDIO_REACTIVE
    anim = ceil(fmod(timeY * 3.0h + _BeatOutput.x * 3.0h, 6.0h));
#else
    anim = ceil(fmod(timeY * 12.0h, 6.0h));
#endif
}

// Dots particle FFT response. The package graph does not expose the original material's
// _WaveformFreq/_WaveformIntensity properties, so these match the source material constants.
void DotsAudioPosition_float(float3 positionOS, out float3 outPositionOS)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4(positionOS, 1)).xyz;
    float waveform = SampleFFTTex(fmod(positionWS.x * 0.1 + _BeatOutputAccum.z * 0.5, 1)).b * 0.25;
    outPositionOS = positionOS + waveform * float3(0, 15, 0);
#else
    outPositionOS = positionOS;
#endif
}
void DotsAudioPosition_half(half3 positionOS, out half3 outPositionOS)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4((float3)positionOS, 1)).xyz;
    float waveform = SampleFFTTex(fmod(positionWS.x * 0.1 + _BeatOutputAccum.z * 0.5, 1)).b * 0.25;
    outPositionOS = (half3)((float3)positionOS + waveform * float3(0, 15, 0));
#else
    outPositionOS = positionOS;
#endif
}

void DotsAudioUV_float(float2 uv, float3 positionOS, out float2 uvOut)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4(positionOS, 1)).xyz;
    float waveform = SampleFFTTex(fmod(positionWS.x * 0.1 + _BeatOutputAccum.z * 0.5, 1)).b * 0.25 * 15;
    float vDistance = abs(uv.y - 0.5) * 2;
    float vStretched = (uv.y - 0.5) * (0.5 - abs(waveform)) * 2 + 0.5;
    uvOut = float2(uv.x, lerp(vStretched, uv.y, vDistance));
#else
    uvOut = uv;
#endif
}
void DotsAudioUV_half(half2 uv, half3 positionOS, out half2 uvOut)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4((float3)positionOS, 1)).xyz;
    float waveform = SampleFFTTex(fmod(positionWS.x * 0.1 + _BeatOutputAccum.z * 0.5, 1)).b * 0.25 * 15;
    float vDistance = abs(uv.y - 0.5) * 2;
    float vStretched = (uv.y - 0.5) * (0.5 - abs(waveform)) * 2 + 0.5;
    uvOut = half2(uv.x, lerp(vStretched, uv.y, vDistance));
#else
    uvOut = uv;
#endif
}

void FireAudioTex_float(float4 texIn, float2 uv, float3 positionOS, float displacement, out float4 texOut)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4(positionOS, 1)).xyz;
    float envelope = sin(uv.x * 3.14159);
    float envelopeHalf = sin(uv.x * 3.14159 * 0.5);

    float waveform = (SampleWaveformTex(uv.x * 0.2 + 0.025 * positionWS.y).g - 0.5) + displacement * 0.05;
    float proceduralLine = pow(abs(1 - abs((uv.y - 0.5) + waveform)), max(100 * uv.x, 0.001));

    waveform = (SampleWaveformTex(uv.x * 0.3 + 0.034 * positionWS.y).w - 0.5) + displacement * 0.02;
    proceduralLine += pow(abs(1 - abs((uv.y - 0.5) + waveform)), max(100 * uv.x, 0.001));

    texOut = texIn * 0.5 + 2 * proceduralLine * (envelope * envelopeHalf);
#else
    texOut = texIn;
#endif
}
void FireAudioTex_half(half4 texIn, half2 uv, half3 positionOS, half displacement, out half4 texOut)
{
#ifdef AUDIO_REACTIVE
    float3 positionWS = mul(unity_ObjectToWorld, float4((float3)positionOS, 1)).xyz;
    float envelope = sin(uv.x * 3.14159);
    float envelopeHalf = sin(uv.x * 3.14159 * 0.5);

    float waveform = (SampleWaveformTex(uv.x * 0.2 + 0.025 * positionWS.y).g - 0.5) + displacement * 0.05;
    float proceduralLine = pow(abs(1 - abs((uv.y - 0.5) + waveform)), max(100 * uv.x, 0.001));

    waveform = (SampleWaveformTex(uv.x * 0.3 + 0.034 * positionWS.y).w - 0.5) + displacement * 0.02;
    proceduralLine += pow(abs(1 - abs((uv.y - 0.5) + waveform)), max(100 * uv.x, 0.001));

    texOut = texIn * 0.5h + 2.0h * proceduralLine * (envelope * envelopeHalf);
#else
    texOut = texIn;
#endif
}

void DiscoAudioPosition_float(float3 graphPosition, float3 basePosition, float3 normal, float4 uv, out float3 outPosition)
{
#ifdef AUDIO_REACTIVE
    float t = _BeatOutputAccum.z * 5;
    float uTileRate = 5;
    float waveIntensity = _PeakBandLevels.y * 0.8 + 0.5;
    float radius = uv.z;
    float waveform = SampleWaveformTex(uv.x * 2).b - 0.5;
    float theta = fmod(uv.y, 1);
    outPosition = basePosition + waveform * normal * 0.2;
    outPosition += pow(1 - (sin(t + uv.x * uTileRate + theta * 10) + 1), 2) * normal * waveIntensity * radius;
#else
    outPosition = graphPosition;
#endif
}
void DiscoAudioPosition_half(half3 graphPosition, half3 basePosition, half3 normal, half4 uv, out half3 outPosition)
{
#ifdef AUDIO_REACTIVE
    float t = _BeatOutputAccum.z * 5;
    float uTileRate = 5;
    float waveIntensity = _PeakBandLevels.y * 0.8 + 0.5;
    float radius = uv.z;
    float waveform = SampleWaveformTex(uv.x * 2).b - 0.5;
    float theta = fmod(uv.y, 1);
    float3 audioPosition = (float3)basePosition + waveform * (float3)normal * 0.2;
    audioPosition += pow(1 - (sin(t + uv.x * uTileRate + theta * 10) + 1), 2) * (float3)normal * waveIntensity * radius;
    outPosition = (half3)audioPosition;
#else
    outPosition = graphPosition;
#endif
}

void HyperGridAudioPosition_float(float3 positionOS, float4 uv1, out float3 outPositionOS)
{
    float3 positionWS = mul(unity_ObjectToWorld, float4(positionOS, 1)).xyz;
    float lifetime = GetBrushTime().y - uv1.w;
    float release = saturate(lifetime);
#ifdef AUDIO_REACTIVE
    positionWS.y -= release * fmod(_BeatOutputAccum.x - uv1.w, 5);
    positionWS.y += 0.3 * release * pow(sin(_BeatOutputAccum.x * 2 + positionWS.x), 5);
#endif
    float size = max(length(uv1.xyz), 0.0001);
    float q = (1.0 / size) * 0.5;
    q += 5.0 * saturate(1.0 - release * 10.0);
    positionWS = ceil(positionWS * q) / q;
    outPositionOS = mul(unity_WorldToObject, float4(positionWS, 1)).xyz;
}
void HyperGridAudioPosition_half(half3 positionOS, half4 uv1, out half3 outPositionOS)
{
    float3 positionWS = mul(unity_ObjectToWorld, float4((float3)positionOS, 1)).xyz;
    float lifetime = GetBrushTime().y - (float)uv1.w;
    float release = saturate(lifetime);
#ifdef AUDIO_REACTIVE
    positionWS.y -= release * fmod(_BeatOutputAccum.x - (float)uv1.w, 5);
    positionWS.y += 0.3 * release * pow(sin(_BeatOutputAccum.x * 2 + positionWS.x), 5);
#endif
    float size = max(length((float3)uv1.xyz), 0.0001);
    float q = (1.0 / size) * 0.5;
    q += 5.0 * saturate(1.0 - release * 10.0);
    positionWS = ceil(positionWS * q) / q;
    outPositionOS = (half3)mul(unity_WorldToObject, float4(positionWS, 1)).xyz;
}

void MusicReactiveColor_float(float4 color, float beat, out float4 outColor)
{
    outColor = OB_MusicReactiveColor(color, beat);
}
void MusicReactiveColor_half(half4 color, half beat, out half4 outColor)
{
    outColor = (half4)OB_MusicReactiveColor((float4)color, beat);
}

void MusicReactiveAnimation_float(float3 positionWS, float4 color, float beat, float t, out float3 outPositionWS)
{
    outPositionWS = OB_MusicReactiveAnimationWS(positionWS, color, beat, t);
}
void MusicReactiveAnimation_half(half3 positionWS, half4 color, half beat, half t, out half3 outPositionWS)
{
    outPositionWS = (half3)OB_MusicReactiveAnimationWS((float3)positionWS, (float4)color, beat, t);
}

// Vertex vibration intercept for the AudioReactiveVertexAnim subgraph: takes an OBJECT-space
// position, the vertex colour, a beat band (0=x..3=w) and t (stroke param, e.g. uv.x); returns
// the modified object-space position. Converts to world space to vibrate (matching the original
// musicReactiveAnimation) then back. Gated; passthrough when off.
void MusicReactiveAnimationBand_float(float3 positionOS, float3 vertexColor, float band, float t, out float3 outPositionOS)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    float3 posWS = mul(unity_ObjectToWorld, float4(positionOS, 1)).xyz;
    posWS = OB_MusicReactiveAnimationWS(posWS, float4(vertexColor, 1), beat, t);
    outPositionOS = mul(unity_WorldToObject, float4(posWS, 1)).xyz;
#else
    outPositionOS = positionOS;
#endif
}
void MusicReactiveAnimationBand_half(half3 positionOS, half3 vertexColor, half band, half t, out half3 outPositionOS)
{
#ifdef AUDIO_REACTIVE
    float beat = band < 0.5 ? _BeatOutput.x
               : band < 1.5 ? _BeatOutput.y
               : band < 2.5 ? _BeatOutput.z
                            : _BeatOutput.w;
    float3 posWS = mul(unity_ObjectToWorld, float4((float3)positionOS, 1)).xyz;
    posWS = OB_MusicReactiveAnimationWS(posWS, float4((float3)vertexColor, 1), beat, t);
    outPositionOS = (half3)mul(unity_WorldToObject, float4(posWS, 1)).xyz;
#else
    outPositionOS = positionOS;
#endif
}

void StandardSingleSidedAudioUV_float(float2 uv, float mode, out float2 uvOut)
{
#ifdef AUDIO_REACTIVE
    if (mode > 0.5 && mode < 1.5)
    {
        float2 audioUV = uv;
        audioUV.x -= _BeatOutputAccum.x;
        audioUV.y += audioUV.x;
        audioUV.x *= 0.25;
        audioUV.y += SampleWaveformTex(audioUV.x).r - 0.5;
        uvOut = audioUV;
        return;
    }
#endif
    uvOut = uv;
}
void StandardSingleSidedAudioUV_half(half2 uv, half mode, out half2 uvOut)
{
#ifdef AUDIO_REACTIVE
    if (mode > 0.5h && mode < 1.5h)
    {
        float2 audioUV = (float2)uv;
        audioUV.x -= _BeatOutputAccum.x;
        audioUV.y += audioUV.x;
        audioUV.x *= 0.25;
        audioUV.y += SampleWaveformTex(audioUV.x).r - 0.5;
        uvOut = (half2)audioUV;
        return;
    }
#endif
    uvOut = uv;
}

void StandardSingleSidedAudioColor_float(float3 colorIn, float2 uv, float mode, out float3 colorOut)
{
#ifdef AUDIO_REACTIVE
    if (mode > 1.5 && mode < 2.5)
    {
        float waveform = SampleFFTTex(0.5 - uv.x).b;
        float proceduralLine = abs(uv.y - 0.5) > waveform ? 0.0 : waveform;
        colorOut = colorIn * proceduralLine;
        return;
    }
#endif
    colorOut = colorIn;
}
void StandardSingleSidedAudioColor_half(half3 colorIn, half2 uv, half mode, out half3 colorOut)
{
#ifdef AUDIO_REACTIVE
    if (mode > 1.5h && mode < 2.5h)
    {
        float waveform = SampleFFTTex(0.5 - (float)uv.x).b;
        float proceduralLine = abs((float)uv.y - 0.5) > waveform ? 0.0 : waveform;
        colorOut = (half3)((float3)colorIn * proceduralLine);
        return;
    }
#endif
    colorOut = colorIn;
}

float OB_AudioCurlX(float3 p, float d)
{
    return ((sin(p.y + d) - sin(p.y - d)) * (sin(p.z + d) + sin(p.z - d))
        - (sin(p.z + d) - sin(p.z - d)) * (sin(p.y + d) + sin(p.y - d))) / (4.0 * d * d);
}

float OB_AudioCurlY(float3 p, float d)
{
    return ((sin(p.z + d) - sin(p.z - d)) * (sin(p.x + d) + sin(p.x - d))
        - (sin(p.x + d) - sin(p.x - d)) * (sin(p.z + d) + sin(p.z - d))) / (4.0 * d * d);
}

float OB_AudioCurlZ(float3 p, float d)
{
    return ((sin(p.x + d) - sin(p.x - d)) * (sin(p.y + d) + sin(p.y - d))
        - (sin(p.y + d) - sin(p.y - d)) * (sin(p.x + d) + sin(p.x - d))) / (4.0 * d * d);
}

void StandardSingleSidedAudioPosition_float(float3 positionOS, float3 normalOS, float2 uv, float4 uv1, float4 vertexColor, float mode, float displacementAmount, float displacementExponent, float scrollRate, float4 scrollDistance, float scrollJitterIntensity, float scrollJitterFrequency, out float3 outPositionOS)
{
    if (mode > 2.5 && mode < 3.5)
    {
        float lifetime = GetBrushTime().y - uv1.w;
        float release = saturate(lifetime * 0.1);
#ifdef AUDIO_REACTIVE
        lifetime = -lifetime * 0.1 + _BeatOutputAccum.x;
#endif
        float3 perVertOffset = uv1.xyz;
        float3 localMidpointPos = positionOS - perVertOffset;
        float d = 10.0 + vertexColor.g * 3.0;
        float freq = 1.5 + vertexColor.r;
        float3 p = localMidpointPos * freq + lifetime;
        float3 curl = float3(OB_AudioCurlX(p, d), OB_AudioCurlY(p, d), OB_AudioCurlZ(p, d));
        localMidpointPos += release * curl * 10.0;
        outPositionOS = localMidpointPos + perVertOffset;
        return;
    }
    if (mode > 3.5 && mode < 4.5)
    {
        outPositionOS = positionOS + normalOS * pow(saturate(uv.x), max(displacementExponent, 0.0001)) * displacementAmount;
        return;
    }
    if (mode > 4.5 && mode < 5.5)
    {
        float seed = vertexColor.a;
        float t01 = fmod(GetBrushTime().y * scrollRate + seed * 10.0, 1.0);
        float t2 = GetBrushTime().y / 3.0;
        float3 disp = scrollDistance.xyz * t01;
        disp.x += sin(t01 * scrollJitterFrequency + seed * 10.0 + t2 + positionOS.z) * scrollJitterIntensity;
        disp.y += (fmod(seed * 100.0, 1.0) - 0.5) * scrollDistance.y * t01;
        disp.z += cos(t01 * scrollJitterFrequency + seed * 7.0 + t2 + positionOS.x) * scrollJitterIntensity;
        outPositionOS = positionOS + disp * 0.1;
        return;
    }
    outPositionOS = positionOS;
}
void StandardSingleSidedAudioPosition_half(half3 positionOS, half3 normalOS, half2 uv, half4 uv1, half4 vertexColor, half mode, half displacementAmount, half displacementExponent, half scrollRate, half4 scrollDistance, half scrollJitterIntensity, half scrollJitterFrequency, out half3 outPositionOS)
{
    float3 outPosition;
    StandardSingleSidedAudioPosition_float((float3)positionOS, (float3)normalOS, (float2)uv, (float4)uv1, (float4)vertexColor, (float)mode, (float)displacementAmount, (float)displacementExponent, (float)scrollRate, (float4)scrollDistance, (float)scrollJitterIntensity, (float)scrollJitterFrequency, outPosition);
    outPositionOS = (half3)outPosition;
}


void SnowVertexPosition_float(float3 positionOS, float4 vertexColor, float scrollRate, float4 scrollDistance, float scrollJitterIntensity, float scrollJitterFrequency, out float3 outPositionOS)
{
    float t = fmod(GetBrushTime().y * scrollRate + vertexColor.a, 1.0);
    float3 disp = (t - 0.5) * scrollDistance.xyz;
    disp.x += sin(t * scrollJitterFrequency + GetBrushTime().y) * scrollJitterIntensity;
    disp.z += cos(t * scrollJitterFrequency * 0.5 + GetBrushTime().y) * scrollJitterIntensity;
    outPositionOS = positionOS + disp * 0.1;
}
void SnowVertexPosition_half(half3 positionOS, half4 vertexColor, half scrollRate, half4 scrollDistance, half scrollJitterIntensity, half scrollJitterFrequency, out half3 outPositionOS)
{
    float3 outPosition;
    SnowVertexPosition_float((float3)positionOS, (float4)vertexColor, (float)scrollRate, (float4)scrollDistance, (float)scrollJitterIntensity, (float)scrollJitterFrequency, outPosition);
    outPositionOS = (half3)outPosition;
}

#endif
