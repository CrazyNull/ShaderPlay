
Shader "Custom/Matcap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CapTex ("Cap Texture",2D) = "white" {}
        [KeywordEnum(World, Camera, Light)] _Scope("Scope", Float) = 0
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
            #pragma multi_compile _SCOPE_WORLD _SCOPE_CAMERA _SCOPE_LIGHT

            #include "UnityCG.cginc"

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
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _CapTex;
            float _CapRotate;
            
            #if _SCOPE_LIGHT
                uniform float4x4 _MainDirLightWorldToLocalMatrix;
            #endif
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                float3 n = (0,0,0);
                #if _SCOPE_WORLD
                    n = UnityObjectToWorldNormal(v.normal);
                #endif

                #if _SCOPE_CAMERA
                    n = mul(UNITY_MATRIX_MV,v.normal);
                #endif

                #if _SCOPE_LIGHT
                    n = mul(_MainDirLightWorldToLocalMatrix,UnityObjectToWorldNormal(v.normal));
                #endif

                o.cap = n.xy * 0.5 + 0.5;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 capCol = tex2D(_CapTex,i.cap);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col * capCol;
            }
            ENDCG
        }
    }
    
    Fallback "VertexLit"
}
