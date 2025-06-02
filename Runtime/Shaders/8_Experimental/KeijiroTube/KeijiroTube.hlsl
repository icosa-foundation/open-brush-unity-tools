void KeijiroTubeVertex_float(
    float2 uv,
    float radius,
    float time,
    float3 posIn,
    float3 normal,
    out float3 posOut)
{
    // float wave = sin(uv.x - time * 2);
    // float pulse = smoothstep(.45, .5, saturate(wave));
    posOut = posIn;
    // We don't currently have radius data in the mesh so this is commented out.
    // We'll do clipping in the fragment shader instead.
    // posOut.xyz -= pulse * radius * normal.xyz;
}

void KeijiroTubeFragment_float(
    float2 uv,
    float time,
    out float alpha)
{
    float wave = sin(uv.x - time * 2);
    alpha = smoothstep(.45, .5, saturate(wave));
}
