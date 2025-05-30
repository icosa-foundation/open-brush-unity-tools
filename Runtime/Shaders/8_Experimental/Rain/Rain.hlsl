// Random number function
float rand_1_05(in float2 uv)
{
    float2 noise = (frac(sin(dot(uv, float2(12.9898, 78.233)*2.0)) * 4550));
    return abs(noise.x) * 0.7;
}

// Rain animation calculation
void CalculateRainUV_float(
    float2 baseUV,
    float time,
    float speed,
    float speedScaling,
    float numSides,
    out float2 animatedUV,
    out float fade)
{
    float u_scale = speed;
    float t = fmod(time * speedScaling * u_scale, u_scale);

    float u = baseUV.x * u_scale - t;

    float row_id = (int)(baseUV.y * numSides);
    float rand = rand_1_05(row_id.xx);

    u += rand * time * 2.75 * u_scale;
    u = fmod(u, u_scale);

    float v = baseUV.y * numSides;

    animatedUV = float2(u, v);
    fade = pow(abs(baseUV.x * 0.25), 9);
}

// Vertex displacement function
void RainVertexDisplace_float(
    float3 vertex,
    float3 normal,
    float radius,
    float bulge,
    out float3 displacedVertex)
{
    displacedVertex = vertex + normal * bulge * radius;
}