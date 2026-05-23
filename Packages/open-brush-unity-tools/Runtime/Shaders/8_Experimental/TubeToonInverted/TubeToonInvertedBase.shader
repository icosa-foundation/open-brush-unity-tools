Shader "TiltBrush/Experimental/TubeToonInvertedBase"
{
    SubShader
    {
        Tags { "RenderPipeline" = "BuiltInPipeline" }
        Cull Back

        CGINCLUDE
        #include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/2_UnlitSpecials/Toon/ToonCommon.cginc"
        #pragma multi_compile_fog
        #pragma target 3.0

        v2f vert(appdata_t v)
        {
            return vertInflate(v, 0);
        }

        fixed4 frag(v2f i) : SV_Target
        {
            fixed4 color = fixed4(0, 0, 0, 1);
            UNITY_APPLY_FOG(i.fogCoord, color);
            return color;
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
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders/2_UnlitSpecials/Toon/ToonCommon.hlsl"

        Varyings vert(Attributes IN)
        {
            return vertInflate(IN, 0);
        }

        half4 frag(Varyings IN) : SV_Target
        {
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
            return half4(0, 0, 0, 1);
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
            #pragma target 3.5
            ENDHLSL
        }
    }
}
