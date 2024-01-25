Shader "TiltBrush/UnlitSpecials/Toon"
{
    Properties
    {
        _MainColor ("MainColor", Color) = (1.0, 1.0, 1.0, 1.0)
        [Toggle(_Inflate)] _InflateToggle ("Inflate", Float) = 0
        _OutlineMax ("Maximum Outline", Range (0,0.5)) = 0.01

        [Enum(Off,0,On,1)] _Blend("__blend", Float) = 0.0
        _SrcBlend("__src", Float) = 1.0
        _DstBlend("__dst", Float) = 0.0
        [Enum(UnityEngine.Rendering.CompareFunction)]_ZWrite("__zw", Float) = 1.0
        [Enum(UnityEngine.Rendering.CullMode)]_Cull("__cull", Float) = 2.0
    }

    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        // #include "Brush.cginc"
        // #include "Noise.cginc"
        #pragma multi_compile __ AUDIO_REACTIVE
        #pragma multi_compile __ TBT_LINEAR_TARGET
        #pragma multi_compile_fog
        #pragma target 3.0
        sampler2D _MainTex;
        float4 _MainTex_ST;
        float _OutlineMax;

        struct appdata_t
        {
            float4 vertex : POSITION;
            fixed4 color : COLOR;
            float3 normal : NORMAL;
            float3 texcoord : TEXCOORD0;
        };

        struct v2f
        {
            float4 vertex : SV_POSITION;
            fixed4 color : COLOR;
            float2 texcoord : TEXCOORD0;
            UNITY_FOG_COORDS(1)
        };

        // From original Brush.cginc
        float4 LinearToSrgb(float4 color)
        {
            // Approximation http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
            float3 linearColor = color.rgb;
            float3 S1 = sqrt(linearColor);
            float3 S2 = sqrt(S1);
            float3 S3 = sqrt(S2);
            color.rgb = 0.662002687 * S1 + 0.684122060 * S2 - 0.323583601 * S3 - 0.0225411470 * linearColor;
            return color;
        }
        float4 TbVertToSrgb(float4 color) { return LinearToSrgb(color); }
        float4 TbVertToNative(float4 color) { return TbVertToSrgb(color); }

        v2f vertInflate(appdata_t v, float inflate)
        {
            v2f o;
            float outlineEnabled = inflate;
            float radius = v.texcoord.z;
            inflate *= radius * .4;
            float bulge = 0.0;
            float3 worldNormal = UnityObjectToWorldNormal(v.normal);

            #ifdef AUDIO_REACTIVE
	        float fft = tex2Dlod(_FFTTex, float4(_BeatOutputAccum.z*.25 + v.texcoord.x, 0,0,0)).g;
	        bulge = fft * radius * 10.0;
            #endif

            //
            // Careful: perspective projection is non-afine, so math assumptions may not be valid here.
            //

            // Technically these are not yet in NDC because they haven't been divided by W, so their
            // range is currently [-W, W].
            o.vertex = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal.xyz * bulge, v.vertex.w));
            float4 outline_NDC = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal.xyz * inflate, v.vertex.w));

            // Displacement in proper NDC coords (e.g. [-1, 1])
            float3 disp = outline_NDC.xyz / outline_NDC.w - o.vertex.xyz / o.vertex.w;

            // Magnitude is a scaling factor to shrink large outlines down to a max width, in NDC space.
            // Notice here we're only measuring 2D displacment in X and Y.
            float mag = length(disp.xy);
            mag = min(_OutlineMax, mag) / mag;

            // Ideally we would project back into world space to do the scaling, but the inverse
            // projection matrix is not currently available. So instead, we multiply back in the w
            // component so both sides of the += operator below are in the same space. Also note
            // that the w component is a function of depth, so modifying X and Y independent of Z
            // should mean that the original w value remains valid.
            o.vertex.xyz += float3(disp.xy * mag, disp.z) * o.vertex.w * outlineEnabled;

            // Push Z back to avoid z-fighting when scaled very small. This is not legit,
            // mathematically speaking and likely causes crazy surface derivitives.
            o.vertex.z -= disp.z * o.vertex.w * outlineEnabled;

            o.color = v.color;
            o.color.a = 1;
            o.color.xyz += worldNormal.y * .2;
            o.color.xyz = max(0, o.color.xyz);
            o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
            UNITY_TRANSFER_FOG(o, o.vertex);
            return o;
        }

        v2f vert(appdata_t v)
        {
            v.color = TbVertToNative(v.color);
            return vertInflate(v, 0);
        }

        v2f vertEdge(appdata_t v)
        {
            // v.color = TbVertToNative(v.color); no need
            return vertInflate(v, 1.0);
        }

        fixed4 fragBlack(v2f i) : SV_Target
        {
            float4 color = float4(0, 0, 0, 1);
            UNITY_APPLY_FOG(i.fogCoord, color);
            return color;
        }

        fixed4 fragColor(v2f i) : SV_Target
        {
            UNITY_APPLY_FOG(i.fogCoord, i.color);
            return i.color;
        }
        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragColor
            ENDCG
        }

        Cull Front
        Pass
        {
            CGPROGRAM
            #pragma vertex vertEdge
            #pragma fragment fragBlack
            ENDCG
        }
    }



    SubShader
    {
        PackageRequirements
        {
            "com.unity.render-pipelines.universal": "11.0"
        }

        Name "Toon"

        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "IgnoreProjector"="True"
            "Queue" = "AlphaTest"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START (UnityPerMaterial)
        half4 _MainColor;
        half _OutlineMax;
        CBUFFER_END




        ENDHLSL

        Pass
        {
            Name "ForwardLit"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            // Cull Back
            // ZWrite On
            // Blend One Zero
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma target 2.0

            #pragma shader_feature_local _Inflate

            struct Attributes
            {
                half4 positionOS : POSITION;
                half4 color : COLOR;
                half3 normalOS : NORMAL;
                half4 tangentOS : TANGENT;
                half4 texcoord : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                half4 positionCS : SV_POSITION;
                half4 color : COLOR;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);

                #ifdef _Inflate
					VertexPositionInputs NDCInput = GetVertexPositionInputs(IN.positionOS.xyz + IN.normalOS.xyz);

					// Technically these are not yet in NDC because they haven't been divided by W, so their
					// range is currently [-W, W].
					float4 outline_NDC = NDCInput.positionCS;

					// Displacement in proper NDC coords (e.g. [-1, 1])
					float3 disp = outline_NDC.xyz / outline_NDC.w - IN.positionOS.xyz / IN.positionOS.w;

					// Magnitude is a scaling factor to shrink large outlines down to a max width, in NDC space.
					// Notice here we're only measuring 2D displacment in X and Y.
					float mag = length(disp.xy);
					mag = min(_OutlineMax, mag) / mag;

                #endif


                OUT.positionCS = vertexInput.positionCS;

                #ifdef _Inflate
					OUT.positionCS.xyz += float3(disp.xy * mag, disp.z) * IN.positionOS.w;

					// Push Z back to avoid z-fighting when scaled very small. This is not legit,
					// mathematically speaking and likely causes crazy surface derivitives.
					OUT.positionCS.z -= disp.z * IN.positionOS.w;
                #endif

                // color
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.color = IN.color;
                OUT.color.a = 1;
                OUT.color.rgb += normalInput.normalWS.y * .2;
                OUT.color.rgb = max(0, OUT.color.rgb);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                return IN.color;
            }
            ENDHLSL
        }
    }
}