void PlasmaFragment_float(
    float4 vertexColor,
    float2 uv,
    UnityTexture2D mainTex,
    float opacityMultiplier,
    float time,
    out float3 finalColor,
    out float finalOpacity
    )
{
    // Tuning constants for 3 lines
    float3 A = float3(0.55, 0.3, 0.7);
    float3 aRate = float3(1.2, 1.0, 1.33);
    float3 M = float3(1.0, 2.2, 1.5);  // kind of a multiplier on A's values
    float3 bRate = float3(1.5, 3.0, 2.25) + M * aRate;
    float3 LINE_POS = 0.5;
    float3 LINE_WIDTH = 0.012;

    // Calculate uvs for each line
    float3 us = A * uv.x - aRate * time;
    float3 tmp = M * A * uv.x - bRate * time;
    tmp = abs(frac(tmp) - 0.5);
    float3 vs = uv.y + 0.4 * vertexColor.a * float3(1, -1, 1) * tmp;
    vs = saturate(lerp((vs - 0.5) * 4, vs, sin((3.14159/2) * vertexColor.a)));

    float4 tex = tex2D(mainTex, float2(us[0], vs[0]));
    tex += tex2D(mainTex, float2(us[1], vs[1]));
    tex += tex2D(mainTex, float2(us[2], vs[2]));

    // render 3 procedural lines
    float3 procline = 1 - saturate(pow((vs - LINE_POS)/LINE_WIDTH, 2));
    tex += dot(procline, float3(1,1,1));

    // adjust brightness; modulate by color
    tex *= 0.8 * (1 + 30 * pow((1 - vertexColor.a), 5));
    vertexColor.a = 1;
    float4 c = vertexColor * tex;
    finalColor = c.rgb * c.a * opacityMultiplier;
    finalOpacity = c.a * opacityMultiplier;
}