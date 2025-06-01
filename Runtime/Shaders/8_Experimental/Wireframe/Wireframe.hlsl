// Helper function for 8x8 Bayer Dithering
// Expects screenPixelPos to be integer-based screen pixel coordinates.
// Output is a float value in the range [0, 1).
float Wireframe_Dither8x8(float2 screenPixelPos) {
    static const int dither_matrix[64] = {
        0,32, 8,40, 2,34,10,42,
        48,16,56,24,50,18,58,26,
        12,44, 4,36,14,46, 6,38,
        60,28,52,20,62,30,54,22,
        3,35,11,43, 1,33, 9,41,
        51,19,59,27,49,17,57,25,
        15,47, 7,39,13,45, 5,37,
        63,31,55,23,61,29,53,21
    };

    // Ensure positive integer indices for the lookup table
    int x_idx = int(fmod(screenPixelPos.x, 8.0f));
    int y_idx = int(fmod(screenPixelPos.y, 8.0f));
    x_idx = (x_idx < 0) ? (x_idx + 8) : x_idx;
    y_idx = (y_idx < 0) ? (y_idx + 8) : y_idx;

    return float(dither_matrix[y_idx * 8 + x_idx]) / 64.0f;
}

void WireframeFragment_float(
    float2 TexCoord,
    float4 VertexColor,
    float Opacity,
    out float3 rgb,
    out float alpha
)
{

    float2 localTexCoord = TexCoord; // Use a local copy if modified
    half w = (abs(localTexCoord.x - 0.5f) > 0.45f) ? 1.0h : 0.0h;
    w += (abs(localTexCoord.y - 0.5f) > 0.45f) ? 1.0h : 0.0h;

    float4 Color = VertexColor * w;
    Color.a *= Opacity;
    rgb = Color.rgb;
    alpha = Color.a;
}
