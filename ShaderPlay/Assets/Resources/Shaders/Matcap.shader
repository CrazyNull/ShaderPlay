
Shader "Custom/Matcap"
{
    Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (1,1,1,1)
        _CapTex ("Cap Texture",2D) = "white" {}
        _CapIntensity("Cap Intensity",Range(0,1)) = 1
        [KeywordEnum(World, Camera, Light)] _Scope("Scope", Float) = 0
        [KeywordEnum(None,Use)] _Light("Light", Float) = 0

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
            #pragma multi_compile _LIGHT_NONE _LIGHT_USE

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
            
            #if _SCOPE_LIGHT
                uniform float4x4 _MainDirLightWorldToLocalMatrix;
            #endif
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
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

                #if _LIGHT_USE
                    o.worldNormal = UnityObjectToWorldNormal(v.normal);
                    o.worldLightDir = UnityWorldSpaceLightDir(v.vertex);
                #endif


                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _DiffuseColor;
                fixed4 capCol = tex2D(_CapTex,i.cap) * _CapIntensity;

                #if _LIGHT_USE
                    float3 worldNormal = normalize(i.worldNormal);
                    float3 worldLightDir = normalize(i.worldLightDir);    
                    fixed diff = max(0,dot(worldNormal,worldLightDir)) * 0.5 + 0.5;
                    col = col * diff * _LightColor0;
                #endif

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col + capCol;
            }
            ENDCG
        }
    }
    
    Fallback "VertexLit"
}
