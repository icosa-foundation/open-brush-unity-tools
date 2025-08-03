void BillboardQuad_float(
float VertexID,
float3 OriginalPosition,
float3 ParticleCenter,
float Rotation,
float3 CameraPosition,
out float3 BillboardPosition
)
{
    const float kRecipSquareRootOfTwo = 0.70710678;

    // Calculate quad size from original vertex position
    float size = length(OriginalPosition - ParticleCenter) * kRecipSquareRootOfTwo;

    // Get corner index (0-3)
    float corner = fmod(VertexID, 4.0);

    // Create world-space basis vectors facing the camera
    float3 forward = normalize(CameraPosition - ParticleCenter);
    float3 worldUp = float3(0, 1, 0);
    float3 right = normalize(cross(worldUp, forward));
    float3 up = cross(forward, right);

    // Apply rotation to the basis vectors
    float c = cos(Rotation);
    float s = sin(Rotation);
    float3 rotatedRight = c * right + s * up;
    float3 rotatedUp = -s * right + c * up;

    // Determine corner offsets
    // Corner layout:  2---3
    //                 |   |
    //                 0---1
    float fUp = (corner == 0.0 || corner == 1.0) ? -1.0 : 1.0;
    float fRight = (corner == 0.0 || corner == 2.0) ? -1.0 : 1.0;

    // Calculate final billboard position
    BillboardPosition = ParticleCenter + fRight * rotatedRight * size + fUp * rotatedUp * size;
}