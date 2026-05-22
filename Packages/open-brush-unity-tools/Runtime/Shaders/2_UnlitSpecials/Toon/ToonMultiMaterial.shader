Shader "TiltBrush/UnlitSpecials/Toon"
{
    Properties
    {
        _OutlineMax ("Maximum Outline", Range (0,0.5)) = 0.01
    }

    SubShader
    {
        Cull Back

        CGINCLUDE
        #include "ToonCommon.cginc"
        #pragma multi_compile __ AUDIO_REACTIVE
        #pragma multi_compile __ TBT_LINEAR_TARGET
        #pragma multi_compile_fog
        #pragma target 3.0

        v2f vert(appdata_t v)
        {
            v.color = TbVertToNative(v.color);
            return vertInflate(v, 0);
        }

        fixed4 frag(v2f i) : SV_Target
        {
            UNITY_APPLY_FOG(i.fogCoord, i.color);
            return i.color;
        }
        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    }

    SubShader
    {
        PackageRequirements
        {
            "com.unity.render-pipelines.universal": "11.0"
        }

        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "ToonCommon.hlsl"

        Varyings vert(Attributes IN)
        {
            return vertInflate(IN, 0);
        }

        half4 frag(Varyings IN) : SV_Target
        {
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
            return IN.color;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend One Zero
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile __ AUDIO_REACTIVE
            #pragma target 2.0
            ENDHLSL
        }
    }
}
