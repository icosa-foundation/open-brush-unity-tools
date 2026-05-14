#include "UnityCG.cginc"

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

// Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
float4 LinearToSrgb(float4 color)
{
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
    float radius = v.texcoord.z > 0 ? v.texcoord.z : _OutlineMax / 0.4;
    inflate *= radius * .4;
    float bulge = 0.0;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);

    o.vertex = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal.xyz * bulge, v.vertex.w));
    float4 outline_NDC = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal.xyz * inflate, v.vertex.w));

    float3 disp = outline_NDC.xyz / outline_NDC.w - o.vertex.xyz / o.vertex.w;

    float mag = length(disp.xy);
    mag = min(_OutlineMax, mag) / mag;

    o.vertex.xyz += float3(disp.xy * mag, disp.z) * o.vertex.w * outlineEnabled;
    o.vertex.z -= disp.z * o.vertex.w * outlineEnabled;

    o.color = v.color;
    o.color.a = 1;
    o.color.xyz += worldNormal.y * .2;
    o.color.xyz = max(0, o.color.xyz);
    o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
    UNITY_TRANSFER_FOG(o, o.vertex);
    return o;
}
