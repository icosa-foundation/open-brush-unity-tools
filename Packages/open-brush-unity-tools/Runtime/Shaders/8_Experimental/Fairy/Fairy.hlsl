// HLSL

// Helper: 2D random function (replace with your implementation if needed)
float2 random2(float2 st) {
    return frac(sin(float2(dot(st, float2(12.9898,78.233)), dot(st, float2(39.3468,11.1357)))) * 43758.5453);
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

// Main Fairy Dot Pattern function
void FairyDotPattern_float(
    float2 uv,                // Input UV coordinates
    float3 color,             // Input color (sRGB)
    float emissionGain,       // Emission gain
    float time,               // Time (z component of _Time)
    out float4 outColor       // Output color (RGBA)
) {
    float2 st = uv;
    st.x *= 5.0;

    float scale1 = 3.0;
    float scale2 = 3.0;

    float2 scaler = floor(st);
    scaler = random2(scaler);
    scaler *= scale1;
    scaler = max(scaler, 1.0);
    scaler = floor(scaler);
    st *= scaler;

    scaler = floor(st);
    scaler = random2(scaler + 234.4);
    scaler *= scale2;
    scaler = max(scaler, 1.0);
    scaler = floor(scaler);
    st *= scaler;

    float2 rc = floor(st);
    st = frac(st);
    st -= 0.5;
    st *= 2.0;

    float rscale = lerp(0.2, 1.0, random2(rc).x);
    st /= rscale;

    float2 offset = random2(rc + 5.0) * 0.1;
    st += offset;

    float r = length(st);
    float lum = 1.0 - r;
    lum -= max(offset.x, offset.y);
    lum = saturate(lum);

    float powpow = random2(rc).x;
    powpow = powpow * 2.0 - 1.0;
    powpow = max(0.3, powpow);
    if (powpow < 0.0) {
        powpow = 1.0 / abs(powpow);
    }
    lum *= 2.0;
    lum = pow(lum, powpow);

    float fadespeed = lerp(0.25, 1.25, random2(rc).x);
    float fadephase = random2(rc).x * 2.0 * 3.14159265;
    float t = sin(time * fadespeed + fadephase) * 0.5 + 0.5;
    lum *= lerp(0.0, 1.0, t);

    float4 bloom = bloomColor(float4(color, 1), lum * emissionGain);
    outColor = lum * bloom;
}