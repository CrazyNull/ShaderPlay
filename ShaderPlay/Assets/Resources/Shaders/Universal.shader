Shader "Custom/Universal"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffuseCol ("Diffuse Color", Color) = (1,1,1,1)

	    _SpecularCol ("Specular Color", Color) = (0,0,0,0)
	    _Smoothness ("Smoothness",Range(0,1)) = 0.5
        _Metallic ("Metallic",Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
                float3 worldNormal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
 
            fixed4 _DiffuseCol;
            fixed4 _SpecularCol;
            fixed _Smoothness;
            fixed _Metallic;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 worldNormal = normalize(i.worldNormal);
	            float3 wolrdLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz,_WorldSpaceLightPos0.w));
                float3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 worldHalfDir = normalize(wolrdLightDir + worldViewDir);

                fixed lambert = max(0,dot(worldNormal,wolrdLightDir)) * 0.5 + 0.5;
                fixed4 diffcol = _DiffuseCol * col * lambert;

                float specPower =  ((2 +_Smoothness) / (2 * 3.1415926535)  * _Smoothness);
                fixed4 specCol = _SpecularCol * pow(max(0,dot(i.worldNormal,worldHalfDir)), max(1,_Smoothness * 5)) * specPower;
                
                col = (diffcol * (1 - _Metallic)) + lerp(specCol, diffcol, _Metallic * 0.5);

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
