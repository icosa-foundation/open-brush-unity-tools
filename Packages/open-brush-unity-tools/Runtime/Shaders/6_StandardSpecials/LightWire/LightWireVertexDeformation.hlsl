#ifndef MYLARTUBE_VERTEX_DEFORMATION
#define MYLARTUBE_VERTEX_DEFORMATION

void lightWireVertex_float(
    float3 position,
    float3 normal,
    float4 uv,
    out float3 modified_position,
    out float3 modified_normal)
{
    float radius = uv.z;
    float envelope = sin(fmod( uv.x * 2, 1.0f) * 3.14159);
    float lights = envelope < .15 ? 1 : 0;
    radius *= 0.9;
    modified_position = position += normal * lights * radius;
    modified_normal = normal;
}

#endif
