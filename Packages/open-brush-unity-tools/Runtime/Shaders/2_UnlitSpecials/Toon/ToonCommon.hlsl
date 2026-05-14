#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
float _OutlineMax;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    half4 color : COLOR;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    half4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings vertInflate(Attributes IN, float inflate)
{
    Varyings OUT;

    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

    VertexPositionInputs baseInput = GetVertexPositionInputs(IN.positionOS.xyz);
    OUT.positionCS = baseInput.positionCS;

    if (inflate > 0)
    {
        float radius = IN.texcoord.z > 0 ? IN.texcoord.z : _OutlineMax / 0.4;
        inflate *= radius * .4;

        VertexPositionInputs inflatedInput = GetVertexPositionInputs(IN.positionOS.xyz + IN.normalOS.xyz * inflate);

        float3 disp = inflatedInput.positionCS.xyz / inflatedInput.positionCS.w
                    - baseInput.positionCS.xyz / baseInput.positionCS.w;

        float mag = length(disp.xy);
        mag = min(_OutlineMax, mag) / mag;

        OUT.positionCS.xyz += float3(disp.xy * mag, disp.z) * baseInput.positionCS.w;
        OUT.positionCS.z -= disp.z * baseInput.positionCS.w;
    }

    VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    OUT.color = IN.color;
    OUT.color.a = 1;
    OUT.color.rgb += normalInput.normalWS.y * .2;
    OUT.color.rgb = max(0, OUT.color.rgb);

    return OUT;
}
