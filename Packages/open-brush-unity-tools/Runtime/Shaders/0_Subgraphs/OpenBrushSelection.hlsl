// Copyright 2020 The Tilt Brush Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Shader Graph Custom Function node for the selection / highlight tint.
//
// Open Brush sets _LeftEyeSelectionColor and _RightEyeSelectionColor to a hue that
// advances with time, with the right eye offset from the left; picking between them by
// eye index is what makes a selected stroke shimmer. SELECTION_ON is enabled on every
// batch material in the selection canvas, HIGHLIGHT_ON by GrabWidget when hovering.
// _DisableSelectionEffect suppresses the tint while capturing sketch thumbnails.
//
// Outside Open Brush none of these globals are set and neither keyword is enabled, so
// this compiles out to a passthrough.
//
// Ported from Open Brush's MobileSelection.cginc. Kept
// self-contained so the package does not depend on files in the app project - if you
// change the maths here, change it there too. The unused _PatternSpeed and
// _InverseLimitedScaleSceneMatrix globals that file declares are not carried over.
//
// Shader Graph pulls Custom Function files in with #include_with_pragmas, so the
// multi_compile below is the one the original surface shaders declared and the graph does
// not need to declare a keyword of its own.

#ifndef OPENBRUSH_SELECTION_INCLUDED
#define OPENBRUSH_SELECTION_INCLUDED

#pragma multi_compile __ SELECTION_ON HIGHLIGHT_ON

float4 _LeftEyeSelectionColor;
float4 _RightEyeSelectionColor;
float4 _BrushColor;
float _DisableSelectionEffect;

// Gets the appropriate selection color depending on the eye being rendered.
float4 OpenBrushGetSelectionColor()
{
  return unity_StereoEyeIndex * _RightEyeSelectionColor +
         (1 - unity_StereoEyeIndex) * _LeftEyeSelectionColor;
}

// Given the current material color, override with selection noise if necessary.
float4 OpenBrushAddSelectColor(float4 inColor)
{
  // Skip selection effect if disabled (e.g., during thumbnail capture)
  if (_DisableSelectionEffect > 0.5)
  {
    return inColor;
  }
#if defined(SELECTION_ON)
  float4 color = OpenBrushGetSelectionColor();
#else
  float4 color = _BrushColor;
#endif
  return inColor * 0.5 + color * 0.5;
}

// Equivalent of the SURF_FRAG_MOBILESELECT macro the surface shaders folded into
// SurfaceOutput.Emission.
void AddSelectionEmission_float(float3 Emission, out float3 Out)
{
#if defined(SELECTION_ON) || defined(HIGHLIGHT_ON)
  Out = Emission + OpenBrushAddSelectColor(float4(0.0, 0.0, 0.0, 0.0)).rgb;
#else
  Out = Emission;
#endif
}

// Equivalent of the FRAG_MOBILESELECT macro, which unlit shaders applied to their final
// colour: a 50/50 blend rather than an additive term. Use this on Base Color in Unlit
// graphs, which have no Emission block.
void ApplySelectionColor_float(float3 Color, out float3 Out)
{
#if defined(SELECTION_ON) || defined(HIGHLIGHT_ON)
  Out = OpenBrushAddSelectColor(float4(Color, 1.0)).rgb;
#else
  Out = Color;
#endif
}

#endif
