
Shader "Custom/Matcap"
{
    Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (1,1,1,1)
        _CapTex ("Cap Texture",2D) = "white" {}
        _CapIntensity("Cap Intensity",Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode" = "Always"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float2 cap : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 worldLightDir : TEXCOORD4;
            };

            fixed4 _DiffuseColor;
            sampler2D _CapTex;
            float _CapRotate;
            float _CapIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                o.cap = mul(UNITY_MATRIX_MV,v.normal).xy * 0.5 + 0.5;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldLightDir = UnityWorldSpaceLightDir(v.vertex);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _DiffuseColor;
                fixed3 capCol = tex2D(_CapTex,i.cap) * _CapIntensity;

                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLightDir = normalize(i.worldLightDir);    

                fixed NDotL = dot(worldNormal,worldLightDir);
                
                fixed diff = max(0,NDotL) * 0.5 + 0.5;
                col = col * diff * _LightColor0;
                col.rgb += capCol;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    
    Fallback "VertexLit"
}
