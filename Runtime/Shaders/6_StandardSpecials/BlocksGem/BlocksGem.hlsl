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

// URP port of the surf() function from the built-in BlocksGem surface shader.
//
// This stays as HLSL rather than graph nodes because Shader Graph's Voronoi node is 2D
// only, and the normal perturbation needs screen-space derivatives of the 3D field.
//
// Albedo is black and the colour is carried entirely by the specular term, so the graph
// uses the Lit target in Specular workflow.

#ifndef BLOCKS_GEM_INCLUDED
#define BLOCKS_GEM_INCLUDED

//
// Voronoi implementation taken from
// https://github.com/Scrawk/GPU-Voronoi-Noise
// (MIT License)
//

//1/7
#define BLOCKS_GEM_K 0.142857142857
//3/7
#define BLOCKS_GEM_Ko 0.428571428571

float3 BlocksGemMod(float3 x, float y) { return x - y * floor(x / y); }
float2 BlocksGemMod(float2 x, float y) { return x - y * floor(x / y); }

// Permutation polynomial: (34x^2 + x) mod 289
float3 BlocksGemPermutation(float3 x)
{
  return BlocksGemMod((34.0 * x + 1.0) * x, 289.0);
}

float2 BlocksGemInoise(float3 P, float jitter)
{
  float3 Pi = BlocksGemMod(floor(P), 289.0);
  float3 Pf = frac(P);
  float3 oi = float3(-1.0, 0.0, 1.0);
  float3 of = float3(-0.5, 0.5, 1.5);
  float3 px = BlocksGemPermutation(Pi.x + oi);
  float3 py = BlocksGemPermutation(Pi.y + oi);

  float3 p, ox, oy, oz, dx, dy, dz;
  float2 F = 1e6;

  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      p = BlocksGemPermutation(px[i] + py[j] + Pi.z + oi); // pij1, pij2, pij3

      ox = frac(p * BLOCKS_GEM_K) - BLOCKS_GEM_Ko;
      oy = BlocksGemMod(floor(p * BLOCKS_GEM_K), 7.0) * BLOCKS_GEM_K - BLOCKS_GEM_Ko;

      p = BlocksGemPermutation(p);

      oz = frac(p * BLOCKS_GEM_K) - BLOCKS_GEM_Ko;

      dx = Pf.x - of[i] + jitter * ox;
      dy = Pf.y - of[j] + jitter * oy;
      dz = Pf.z - of + jitter * oz;

      float3 d = dx * dx + dy * dy + dz * dz; // dij1, dij2 and dij3, squared

      //Find lowest and second lowest distances
      for (int n = 0; n < 3; n++) {
        if (d[n] < F[0]) {
          F[1] = F[0];
          F[0] = d[n];
        } else if (d[n] < F[1]) {
          F[1] = d[n];
        }
      }
    }
  }
  return F;
}

// fractal sum, range -1.0 - 1.0
float2 BlocksGemFbmF0(float3 p, float frequency, float jitter)
{
  float freq = frequency, amp = 0.5;
  float2 F = BlocksGemInoise(p * freq, jitter) * amp;
  return F;
}

void BlocksGemSurface_float(
    float3 PositionOS,
    float3 ViewDirTS,
    float3 ViewDirWS,
    float3 TangentWS,
    float3 BitangentWS,
    float3 NormalWS,
    float4 Color,
    float Shininess,
    float RimIntensity,
    float RimPower,
    float Frequency,
    float Jitter,
    out float3 NormalTSOut,
    out float3 Specular,
    out float Smoothness,
    out float3 Emission)
{
  const float kPerturbIntensity = 10;
  float2 F = BlocksGemFbmF0(PositionOS, Frequency, Jitter);
  float gem = (F.y - F.x);

  // Perturb normal with voronoi cells

  // Note: can't do "o.Normal += perturb" because tangent-space o.Normal
  // comes in as (0, 0, 0), not (0, 0, 1)
  NormalTSOut = (float3(0, 0, 1) +
                 kPerturbIntensity * float3(ddy(gem), ddx(gem), 0));

  // WorldReflectionVector() in the built-in surface shader: take the perturbed
  // tangent-space normal into world space and reflect the world view direction off it.
  float3 normalWS = normalize(TangentWS * NormalTSOut.x +
                              BitangentWS * NormalTSOut.y +
                              NormalWS * NormalTSOut.z);
  float3 worldRefl = reflect(-normalize(ViewDirWS), normalWS);

  // Artifical diffraction highlights to simulate what I see in blocks. Tuned to taste.
  float3 refl = clamp(worldRefl + gem, -1.0, 1.0);
  float3 colorRamp = float3(1, .3, 0) * sin(refl.x * 30) +
                     float3(0, 1, .5) * cos(refl.y * 37.77) +
                     float3(0, 0, 1) * sin(refl.z * 43.33);

  Specular = Color.rgb + colorRamp * .1;
  Smoothness = Shininess;

  // Artificial rim lighting
  Emission = (pow(1 - saturate(dot(ViewDirTS, NormalTSOut)), RimPower)) * RimIntensity;
}

#endif
