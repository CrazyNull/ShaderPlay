Shader "Unlit/LowPoly_Diffuse"
{
   Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
        LOD 100
        
        CGINCLUDE

        #include "UnityCG.cginc"
        #include "Lighting.cginc"

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
            float3 worldNormal : TEXCOORD1;
            float3 worldLightDir : TEXCOORD2;
        };

        fixed4 _DiffuseColor;

        v2f vert (appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
            o.worldNormal = UnityObjectToWorldNormal(v.normal);
            o.worldLightDir = UnityWorldSpaceLightDir(v.vertex);
            return o;
        }

        fixed4 frag (v2f i) : SV_Target
        {
            float3 worldNormal = normalize(i.worldNormal);
            float3 worldLightDir = normalize(i.worldLightDir);
                
            fixed diff = max(0,dot(worldNormal,worldLightDir)) * 0.5 + 0.5;
            fixed4 col = _DiffuseColor * diff * _LightColor0;
            return col;
        }
        ENDCG

        Pass
        {
            Tags { "LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ForwardAdd"}
            Blend DstColor SrcColor 
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    }
}
