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

// Shader calculates flat triangle normals from world-position derivatives.
// Avoid geometry stages so the brush also works with mobile XR multiview.
// Uses Blinn-Phong lighting model for the main directional light and SH
// for all additional lighting.
//
// Contains two SubShaders so the shader works in both the Universal Render
// Pipeline and the built-in render pipeline. Unity selects the compatible
// one at runtime: the URP SubShader carries the "UniversalPipeline" tag and a
// PackageRequirements block (so it is skipped when URP is not installed), and
// the untagged SubShader below is the original pre-URP implementation.
Shader "Brush/FlatLit" {

Properties {
  _MainTex("Texture", 2D) = "white" {}
  _Smoothness("Smoothness", Range(0, 1)) = 0.5
  _Metallic("Metallic", Range(0, 1)) = 0

  _Dissolve("Dissolve", Range(0, 1)) = 1
	_ClipStart("Clip Start", Float) = 0
	_ClipEnd("Clip End", Float) = -1
}

// ---------------------------------------------------------------------------
// Universal Render Pipeline
// ---------------------------------------------------------------------------
SubShader {
  PackageRequirements {
    "com.unity.render-pipelines.universal": "11.0"
  }
  Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
  Pass {
    Tags { "LightMode" = "UniversalForward" }
    Blend SrcAlpha OneMinusSrcAlpha
    Cull Back
    HLSLPROGRAM

    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile_instancing
    #pragma target 3.5
    #pragma multi_compile __ SHADER_SCRIPTING_ON
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
    #pragma multi_compile_fragment _ _SHADOWS_SOFT

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);

    CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float _Smoothness;
    float _Metallic;
    half _ClipStart;
    half _ClipEnd;
    half _Dissolve;
    CBUFFER_END

    struct Attributes {
      float4 positionOS : POSITION;
      float2 uv : TEXCOORD0;
      float4 color : COLOR;
      uint id : SV_VertexID;

      UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings {
      float4 positionCS : SV_POSITION;
      float2 uv : TEXCOORD0;
      float3 positionWS : TEXCOORD2;
      float4 color : TEXCOORD3;
      float id : TEXCOORD4;

      UNITY_VERTEX_INPUT_INSTANCE_ID
      UNITY_VERTEX_OUTPUT_STEREO
    };

    float Dither8x8(float2 position) {
      const float DitherSize = 8.0;
      float2 ditherPosition = position % DitherSize;
      int x = int(ditherPosition.x);
      int y = int(ditherPosition.y);

      const float dither8x8[64] = {
        0,32,8,40,2,34,10,42,
        48,16,56,24,50,18,58,26,
        12,44,4,36,14,46,6,38,
        60,28,52,20,62,30,54,22,
        3,35,11,43,1,33,9,41,
        51,19,59,27,49,17,57,25,
        15,47,7,39,13,45,5,37,
        63,31,55,23,61,29,53,21
      };

      return dither8x8[y * 8 + x] / 64.0;
    }

    Varyings vert(Attributes v) {
      Varyings o = (Varyings)0;
      UNITY_SETUP_INSTANCE_ID(v);
      UNITY_TRANSFER_INSTANCE_ID(v, o);
      UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
      VertexPositionInputs posInput = GetVertexPositionInputs(v.positionOS.xyz);
      o.positionCS = posInput.positionCS;
      o.positionWS = posInput.positionWS;
      o.uv = TRANSFORM_TEX(v.uv, _MainTex);
      o.color = v.color;
      o.id = (float)v.id;
      return o;
    }

    half4 frag(Varyings i) : SV_TARGET {
      UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
      // Evaluate derivatives before any discard, while all lanes are active.
      float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);
      float3 normalWS = normalize(cross(ddy(i.positionWS), ddx(i.positionWS)));
      // Back faces are culled; orient the face normal toward the current eye.
      // This also handles render-target Y flips without requiring mesh normals.
      if (dot(normalWS, viewDir) < 0) normalWS = -normalWS;
      #ifdef SHADER_SCRIPTING_ON
      if (_ClipEnd > 0 && !(i.id > _ClipStart && i.id < _ClipEnd)) discard;
      if (_Dissolve < 1 && Dither8x8(i.positionCS.xy) >= _Dissolve) discard;
      #endif

      Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
      half3 lightColor = mainLight.color * mainLight.shadowAttenuation;

      half3 halfDir = normalize(mainLight.direction + viewDir);
      half nDotL = saturate(dot(normalWS, mainLight.direction));

      half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * (1 - _Metallic);
      half3 specularTint = albedo * _Metallic;

      half3 diffuse = albedo * lightColor * nDotL;
      half3 specular = specularTint * lightColor * pow(saturate(dot(halfDir, normalWS)), _Smoothness * 100);
      half3 lighting = diffuse + specular;
      lighting += SampleSH(normalWS) * 0.5;

      return half4(lighting * i.color.rgb, i.color.a);
    }

    ENDHLSL
  }

  // Cast shadows
  Pass {
    Tags { "LightMode" = "ShadowCaster"}

    HLSLPROGRAM
    #pragma target 3.5
    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile_instancing

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    struct Attributes {
      float4 positionOS : POSITION;

      UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings {
      float4 positionCS : SV_POSITION;

      UNITY_VERTEX_INPUT_INSTANCE_ID
      UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings vert(Attributes v) {
      Varyings o = (Varyings)0;
      UNITY_SETUP_INSTANCE_ID(v);
      UNITY_TRANSFER_INSTANCE_ID(v, o);
      UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
      o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
      return o;
    }

    half4 frag() : SV_TARGET {
      return 0;
    }

    ENDHLSL
  }
}

// ---------------------------------------------------------------------------
// Built-in Render Pipeline
// ---------------------------------------------------------------------------
SubShader {
  Tags { "RenderType" = "Opaque" }
  Pass {
    Tags { "LightMode" = "ForwardBase" }
    Blend SrcAlpha OneMinusSrcAlpha
    Cull Back
    CGPROGRAM

    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile __ SHADER_SCRIPTING_ON
    #pragma multi_compile _ SHADOWS_SCREEN
    #pragma multi_compile_instancing
    #pragma target 3.5

    #include "UnityCG.cginc"
    #include "AutoLight.cginc"
    #include "UnityLightingCommon.cginc"

    float _Smoothness;
    float _Metallic;
    sampler2D _MainTex;
    float4 _MainTex_ST;

    uniform half _ClipStart;
    uniform half _ClipEnd;
    uniform half _Dissolve;

    float Dither8x8(float2 position) {
      const float DitherSize = 8.0;
      float2 ditherPosition = position % DitherSize;
      int x = int(ditherPosition.x);
      int y = int(ditherPosition.y);

      const float dither8x8[64] = {
        0,32,8,40,2,34,10,42,
        48,16,56,24,50,18,58,26,
        12,44,4,36,14,46,6,38,
        60,28,52,20,62,30,54,22,
        3,35,11,43,1,33,9,41,
        51,19,59,27,49,17,57,25,
        15,47,7,39,13,45,5,37,
        63,31,55,23,61,29,53,21
      };

      return dither8x8[y * 8 + x] / 64.0;
    }

    struct appdata {
      float4 vertex : POSITION;
      float2 uv : TEXCOORD0;
      float4 color : COLOR;
      uint id : SV_VertexID;

      UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2f {
      float4 pos : SV_POSITION;
      float2 uv : TEXCOORD0;
      float3 worldPos : TEXCOORD2;
      float4 color : TEXCOORD3;
      float id : TEXCOORD4;
      SHADOW_COORDS(5)

      UNITY_VERTEX_OUTPUT_STEREO
    };

    v2f vert(appdata v) {
      v2f o;

      UNITY_SETUP_INSTANCE_ID(v);
      UNITY_INITIALIZE_OUTPUT(v2f, o);
      UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

      o.uv = TRANSFORM_TEX(v.uv, _MainTex);
      o.pos = UnityObjectToClipPos(v.vertex);
      o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
      o.color = v.color;
      o.id = (float)v.id;
      TRANSFER_SHADOW(o);

      return o;
    }

    float4 frag(v2f i) : SV_TARGET {
      UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
      // Keep derivatives outside the scripting discard branches.
      float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
      float3 normal = normalize(cross(ddy(i.worldPos), ddx(i.worldPos)));
      if (dot(normal, viewDir) < 0) normal = -normal;

      #ifdef SHADER_SCRIPTING_ON
      if (_ClipEnd > 0 && !(i.id > _ClipStart && i.id < _ClipEnd)) discard;
      if (_Dissolve < 1 && Dither8x8(i.pos.xy) >= _Dissolve) discard;
      #endif

      // Apply shadows
      UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
      float3 lightColor = _LightColor0.rgb * attenuation;

      // Add main directional light's effect.

      // Calculate vectors to be used in lighting model.
      float3 lightDir = _WorldSpaceLightPos0.xyz;
      float3 halfDir = normalize(lightDir + viewDir);
      float nDotl = saturate(dot(normal, normalize(lightDir)));

      float3 albedo = tex2D(_MainTex, i.uv).rgb * (1 - _Metallic);
      // This is an oversimplification, even pure dielectrics can have some specular
      // reflection, but its good enough for this purpose (and can be toggled in inspector).
      float3 specularTint = albedo * (_Metallic);

      // Blinn-Phong model
      float3 diffuse = albedo * lightColor * nDotl;
      float3 specular = specularTint * lightColor *
                        pow(saturate(dot(halfDir, normal)), _Smoothness * 100);
      float3 lighting = diffuse + specular;

      // Add all other lights in scene.

      // Reduce this component to minimize double counting of main directional light.
      lighting += float3(ShadeSH9(half4(normal, 1.0))) * 0.5;

      return float4(lighting * i.color.rgb, i.color.a);
    }

    ENDCG
  }

  // Cast shadows
  Pass {
    Tags { "LightMode" = "ShadowCaster"}

    CGPROGRAM

    #pragma target 3.5
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"

    struct appdata {
      float4 position : POSITION;
    };

    float4 vert(appdata v) : SV_POSITION {
      float4 position = UnityObjectToClipPos(v.position);
      return UnityApplyLinearShadowBias(position);
    }

    half4 frag() : SV_TARGET {
      return 0;
    }

    ENDCG
  }
}
}
