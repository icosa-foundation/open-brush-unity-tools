// Utility: RGB <-> HSV conversion (as used in UnityCG.cginc)
float3 RGBtoHSV(float3 c) {
    float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HSVToRGB(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

// Fractional part
float frac(float x) { return x - floor(x); }

// Clamped remap
float clampedRemap(float a, float b, float c, float d, float t) {
    float v = (t - a) / (b - a);
    v = saturate(v);
    return lerp(c, d, v);
}


//
// Description : Array and textureless GLSL 2D simplex noise function.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//
float4 mod289(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}
float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float2 mod289(float2 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float mod289(float x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float permute(float x) {
    return mod289(((x*34.0)+1.0)*x);
}

float3 permute(float3 x) {
    return mod289(((x*34.0)+1.0)*x);
}

float4 permute(float4 x) {
    return mod289(((x*34.0)+1.0)*x);
}

float snoise(float2 v) {
    const float4 C = float4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                       -0.577350269189626,  // -1.0 + 2.0 * C.x
                        0.024390243902439); // 1.0 / 41.0
    // First corner
    float2 i  = floor(v + dot(v, C.yy) );
    float2 x0 = v -   i + dot(i, C.xx);

    // Other corners
    float2 i1;
    //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
    //i1.y = 1.0 - i1.x;
    i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    // x0 = x0 - 0.0 + 0.0 * C.xx ;
    // x1 = x0 - i1 + 1.0 * C.xx ;
    // x2 = x0 - 1.0 + 2.0 * C.xx ;
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    float3 p = permute( permute( i.y + float3(0.0, i1.y, 1.0 ))
          + i.x + float3(0.0, i1.x, 1.0 ));

    float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;

    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

    // Compute final noise value at P
    float3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float fbm(float2 st)
{
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    for (int i = 0; i < 6; i++) {
        value += amplitude * snoise(st);
        st *= 2.;
        amplitude *= 0.516;
    }
    return value;
}

// Unity only guarantees signed 2.8 for fixed4.
// In practice, 2*exp(_EmissionGain * 10) = 180, so we need to use float4
float4 bloomColor(float4 color, float gain) {
    // Guarantee that there's at least a little bit of all 3 channels.
    // This makes fully-saturated strokes (which only have 2 non-zero
    // color channels) eventually clip to white rather than to a secondary.
    float cmin = length(color.rgb) * .05;
    color.rgb = max(color.rgb, float3(cmin, cmin, cmin));
    // If we try to remove this pow() from .a, it brightens up
    // pressure-sensitive strokes; looks better as-is.
    color = pow(color, 2.2);
    color.rgb *= 2 * exp(gain * 10);
    return color;
}

// Main color function for Shader Graph Custom Block
void SpaceFragment_float(
    float2 texcoord,
    float3 color_srgb,
    float time,
    float emissionGain,
    out float4 outColor
) {
    float analog_spread = 0.1;
    float gain = 10;
    float gain2 = 0;

    float3 i_HSV = RGBtoHSV(color_srgb);

    float primary_hue = i_HSV.x;
    float analog1_hue = frac(primary_hue - analog_spread);
    float analog2_hue = frac(primary_hue + analog_spread);

    float r = abs(texcoord.y * 2 - 1);

    float primary_a = 0.2 * fbm(texcoord + time) * gain + gain2;
    float analog1_a = 0.2 * fbm(float2(texcoord.x + 12.52, texcoord.y + 12.52) + time * 5.2) * gain + gain2;
    float analog2_a = 0.2 * fbm(float2(texcoord.x + 6.253, texcoord.y + 6.253) + time * 0.8) * gain + gain2;

    primary_a = clampedRemap(0, 0.5, primary_a, 0, r + fbm(float2(time + 50, texcoord.x)) * 2);
    analog1_a = clampedRemap(0.2, 1, 0, analog1_a * 1.2, r);
    analog2_a = clampedRemap(0.2, 1, 0, analog2_a * 1.2, r);

    float a = primary_a + analog1_a + analog2_a;

    float final_hue =
        primary_a * primary_hue +
        analog1_a * analog1_hue +
        analog2_a * analog2_hue;
    final_hue /= max(a, 1e-5);

    float lum = 1 - r;
    float rfbm = fbm(float2(texcoord.x, time));
    rfbm += 1.2;
    rfbm *= 0.8;
    lum *= step(r, rfbm);
    lum *= smoothstep(rfbm, rfbm - 0.2, r);

    float3 rgb = HSVToRGB(float3(final_hue, i_HSV.y, i_HSV.z * lum));
    rgb = saturate(rgb);  // i'm not sure why it's so bright without this
    outColor = bloomColor(float4(rgb, 1), emissionGain);
}