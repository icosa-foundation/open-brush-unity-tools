void BubbleWandSurface_float(
    float3 ViewDirection,
    float3 Normal,
    float3 BaseColor,
    float Time,
    float2 UV,
    Texture2D DiffractionTexture,
    SamplerState DiffractionSampler,
    out float3 Specular,
    out float Smoothness,
    out float3 Emission)
{
    // Hardcoded specular values
    Smoothness = 0.9;
    Specular = 0.6 * BaseColor;
    
    // Calculate rim
    float3 n = Normal;
    half rim = 1.0 - abs(dot(normalize(ViewDirection), n));
    rim *= 1.0 - pow(rim, 5);
    
    // The original Tilt shader sampled diffraction with GetTime().x. Shader Graph's
    // BrushTime input supplies GetTime().y, whose Unity time-vector scale is 20x.
#ifdef _IS_TILT_MESH
    float diffractionTime = Time * 0.05;
#else
    // Preserve the package's existing exported-mesh behavior.
    float diffractionTime = Time;
#endif
    float2 diffractionUV = float2(rim + diffractionTime + Normal.y, rim + Normal.y);
    float3 diffraction = DiffractionTexture.SampleLevel(DiffractionSampler, diffractionUV, 0).xyz;
    
    // Final emission
    Emission = rim * (0.25 * diffraction * rim + 0.75 * diffraction * BaseColor);
}
