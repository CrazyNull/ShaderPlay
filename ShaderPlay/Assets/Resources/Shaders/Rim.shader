Shader "Custom/Rim"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RimColor ("Rim Color",Color) = (1,1,1,1)
        _RimIntensity ("Rim Intensity",Range(0,2)) = 1
    }
    SubShader
    {
        Tags {"Queue" = "Transparent"  "RenderType"="Transparent" }
        LOD 100
        
        Pass 
        {
            ZWrite On
            ColorMask 0
        }

        Pass
        {
            Blend SrcAlpha One
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

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

                float4 worldPos : TEXCOORD2;
                float4 worldNormal : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            fixed4 _RimColor;
            float _RimIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.worldNormal = mul(unity_ObjectToWorld,v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 worldNormal = normalize(i.worldNormal);
                fixed val = 1 - saturate(dot(worldNormal,worldViewDir));
                col = col * _RimColor * val * (1 + _RimIntensity);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
