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

// Shader Graph Custom Function node for Omni-Directional Stereo rendering.
//
// ODS capture needs a different eye position for every azimuth, which a rasteriser cannot
// do, so the geometry is displaced in the vertex shader instead. Open Brush drives this
// from OdsSlice / OdsStereoCubemap; outside Open Brush the globals are never set and the
// keywords are never enabled, so this compiles out to a passthrough.
//
// Ported from Open Brush's Ods.cginc. Kept self-contained so the
// package does not depend on files in the app project - if you change the maths here,
// change it there too.
//
// Shader Graph pulls Custom Function files in with #include_with_pragmas, so the
// multi_compile below is the one the original surface shaders declared and the graph does
// not need to declare a keyword of its own.

#ifndef OPENBRUSH_ODS_INCLUDED
#define OPENBRUSH_ODS_INCLUDED

#pragma multi_compile __ ODS_RENDER ODS_RENDER_CM

uniform float4 ODS_EyeOffset;
uniform float4 ODS_CameraPos;
uniform float ODS_PoleCollapseAmount;

// Elevation of the vertex relative to the capture centre, normalised and eased: roughly 0
// at the horizon, rising towards the poles. Stereo cannot be reconciled at the zenith and
// nadir, so the interocular distance is faded out there.
float OpenBrushCollapseIpd(float3 camOffset)
{
  // URP's ShaderLibrary/Macros.hlsl already defines PI, so these cannot reuse the names
  // the built-in-pipeline original used.
  const float kPi = 3.14159265359;
  const float kHalfPi = kPi / 2;

  float3 vcam = float3(camOffset.x, 0, camOffset.z);
  float d = dot(normalize(camOffset), normalize(vcam));
  float ang = acos(clamp(d, -1, 1));

  const float minAng = 0.0;
  const float maxAng = kHalfPi * 0.8;

  float t = clamp((ang - minAng) / (maxAng - minAng), 0.0, 1.0);

  // Create a continuous falloff for IPD attenuation at the poles.
  return sin(t / (2.0 * kPi)) * ODS_PoleCollapseAmount;
}

void OpenBrushPrepForOdsWorldSpace_CM(inout float4 vertex)
{
#ifdef ODS_RENDER_CM
  float3 worldUp = float3(0.0, 1.0, 0.0);
  float3 camOffset = vertex.xyz - _WorldSpaceCameraPos.xyz;

  //Direction
  float4 D = float4(camOffset.xyz, dot(camOffset.xyz, camOffset.xyz));
  if (dot(D.xz, D.xz) < 0.00001) return;
  D *= rsqrt(D.w);

  //Tangent (note this is not the sphere tangent)
  float3 T = normalize(cross(D.xyz, worldUp.xyz));

  //reduce the IPD towards the poles (Tilt Brush specific)
  float t = OpenBrushCollapseIpd(camOffset);
  float ipd = lerp(ODS_EyeOffset.x, 0.0, t);

  float a = ipd * ipd / D.w;
  float b = ipd / D.w * sqrt(D.w * D.w - ipd * ipd);

  float3 offset = -a * D.xyz + b * T;

  vertex.xyz = vertex.xyz + offset;
#endif
}

void OpenBrushPrepForOdsWorldSpace(inout float4 vertex)
{
#if defined(ODS_RENDER_CM)
  OpenBrushPrepForOdsWorldSpace_CM(vertex);
#elif defined(ODS_RENDER)
  float3 vcamVert = vertex.xyz - ODS_CameraPos.xyz;
  if (dot(vcamVert.xz, vcamVert.xz) < 0.00001) return;
  float t = OpenBrushCollapseIpd(vcamVert);

  // Dragging the geometry along with the eye cancels the camera's own offset, which is
  // what collapses the effective IPD towards the poles.
  vertex.xyz += lerp(float3(0, 0, 0), ODS_EyeOffset.xyz, t);
#endif
}

void ApplyOds_float(float3 PositionOS, out float3 Out)
{
#if defined(ODS_RENDER) || defined(ODS_RENDER_CM)
  float4 vertex = mul(UNITY_MATRIX_M, float4(PositionOS, 1.0));
  OpenBrushPrepForOdsWorldSpace(vertex);
  Out = mul(UNITY_MATRIX_I_M, vertex).xyz;
#else
  Out = PositionOS;
#endif
}

#endif
