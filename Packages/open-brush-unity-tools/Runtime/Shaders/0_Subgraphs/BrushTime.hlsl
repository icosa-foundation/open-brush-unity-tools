#ifndef OPENBRUSH_BRUSH_TIME_INCLUDED
#define OPENBRUSH_BRUSH_TIME_INCLUDED

float4 GetBrushTime()
{
#ifdef SHADER_SCRIPTING_ON
    return lerp(_Time * _TimeSpeed, _TimeOverrideValue, _TimeBlend);
#else
    return _Time;
#endif
}

void BrushTime_float(
    out float Time,
    out float SineTime,
    out float CosineTime,
    out float DeltaTime,
    out float SmoothDelta)
{
    float4 brushTime = GetBrushTime();
    Time = brushTime.y;
    SineTime = sin(brushTime.y);
    CosineTime = cos(brushTime.y);
    DeltaTime = unity_DeltaTime.x;
    SmoothDelta = unity_DeltaTime.z;
}

void BrushTime_half(
    out half Time,
    out half SineTime,
    out half CosineTime,
    out half DeltaTime,
    out half SmoothDelta)
{
    float4 brushTime = GetBrushTime();
    Time = (half)brushTime.y;
    SineTime = (half)sin(brushTime.y);
    CosineTime = (half)cos(brushTime.y);
    DeltaTime = (half)unity_DeltaTime.x;
    SmoothDelta = (half)unity_DeltaTime.z;
}

#endif
