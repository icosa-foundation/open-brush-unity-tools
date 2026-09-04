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

// URP port of the surf() function from the built-in BlocksGlass surface shader.
//
// Albedo is black and the colour is carried entirely by the specular term, so the graph
// uses the Lit target in Specular workflow.
//
// The normal is flat in tangent space and flipped by hand for back faces. URP does not
// flip it for us: PBRForwardPass.hlsl builds tangentToWorld from the interpolated basis
// with no FaceSign applied, so this reproduces the original VFACE behaviour rather than
// double-flipping it.

#ifndef BLOCKS_GLASS_INCLUDED
#define BLOCKS_GLASS_INCLUDED

void BlocksGlassSurface_float(
    float VFace,
    float3 ViewDirTS,
    float4 Color,
    float Shininess,
    float RimIntensity,
    float RimPower,
    out float3 NormalTS,
    out float3 Specular,
    out float Smoothness,
    out float3 Emission)
{
  // VFace is +1 on front faces and -1 on back faces, fed from an Is Front Face node
  // through a Branch, which is how the graph reproduces the old VFACE semantic.
  NormalTS = float3(0.0, 0.0, VFace);

  // Dim backfaces
  float backfaceDimming = VFace < 0.0 ? 0.25 : 1.0;

  Specular = Color.rgb * backfaceDimming;
  Smoothness = Shininess;

// Currently rim lighting is causing the entire object to go white in ODS renders.
// TODO: figure out what's causing this.
#if defined(ODS_RENDER_CM)
  Emission = float3(0.0, 0.0, 0.0);
#else
  // Rim Lighting
  Emission = pow(1.0 - saturate(dot(ViewDirTS, NormalTS)), RimPower) * RimIntensity * backfaceDimming;
#endif
}

#endif
