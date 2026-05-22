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

#endif
