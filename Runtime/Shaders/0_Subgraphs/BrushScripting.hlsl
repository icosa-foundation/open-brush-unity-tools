float BrushScripting_Dither8x8(float2 screenPixelPos)
{
    static const int dither_matrix[64] = {
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21
    };
    int x = int(fmod(abs(screenPixelPos.x), 8.0));
    int y = int(fmod(abs(screenPixelPos.y), 8.0));
    return float(dither_matrix[y * 8 + x]) / 64.0;
}

// VertexID is interpolated from vertex stage - gives smooth clip boundary at stroke end
// ScreenPos is raw clip-space position (divide by .w for NDC)
// Dissolve: 1.0 = fully visible, 0.0 = fully dissolved
// ClipEnd <= 0 means no clipping active
void BrushScripting_float(
    float4 ColorIn,
    float VertexID,
    float4 ScreenPos,
    float Dissolve,
    float ClipStart,
    float ClipEnd,
    out float4 ColorOut)
{
    ColorOut = ColorIn;
    if (ClipEnd > 0 && !(VertexID > ClipStart && VertexID < ClipEnd))
        clip(-1);
    if (Dissolve < 1)
    {
        float2 screenPixels = ScreenPos.xy / ScreenPos.w * _ScreenParams.xy;
        if (BrushScripting_Dither8x8(screenPixels) >= Dissolve)
            clip(-1);
    }
}
