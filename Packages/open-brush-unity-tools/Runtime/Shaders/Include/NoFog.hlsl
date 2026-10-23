#ifndef OPEN_BRUSH_NO_FOG_INCLUDED
#define OPEN_BRUSH_NO_FOG_INCLUDED

// These graphs replace surface shaders authored with "nofog". Shader Graph's
// lit targets always apply fog in their generated forward passes. Override only
// that final blend in shaders including this file, leaving lighting and the
// scene's fog settings intact. Load the pipeline helpers before defining the
// macros so their function declarations are not affected.
#if defined(UNIVERSAL_PIPELINE_CORE_INCLUDED)
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#define MixFog(color, fogFactor) (color)
#else
#include "UnityCG.cginc"
#undef UNITY_APPLY_FOG
#define UNITY_APPLY_FOG(coord, color)
#undef UNITY_APPLY_FOG_COLOR
#define UNITY_APPLY_FOG_COLOR(coord, color, fogColor)
#endif

#endif
