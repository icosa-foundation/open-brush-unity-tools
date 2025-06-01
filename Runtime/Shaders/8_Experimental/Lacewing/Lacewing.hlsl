
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

    spectex.rgb = float3(1, 0, 0) * (sin(spectex.r * 2 + scroll * 0.5 - specuv.x) + 1) * 1;
    spectex.rgb += float3(0, 1, 0) * (sin(spectex.r * 3.3 + scroll * 1 - specuv.x) + 1) * 1;
    spectex.rgb += float3(0, 0, 1) * (sin(spectex.r * 4.66 + scroll * 0.25 - specuv.x) + 1) * 1;

    color = (tex * vertexColor).rgb;
    specColor = (specTint * spectex).rgb;
    alpha = tex.a * vertexColor.a;
}