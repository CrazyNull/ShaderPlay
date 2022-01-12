Shader "Custom/Deferred_Diffuse"
{
    Properties
    {
        _MainTex("Texture",2D) = "white"{}
        _Diffuse ("Diffuse Color", Color) = (1,1,1,1)
		_Specular("Specular Color",Color) = (1,1,1,1)
		_Gloss("Gloss",Range(8.0,256)) = 8.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
        LOD 100
        
        CGINCLUDE

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
            float4 vertex : SV_POSITION;
            float3 worldPos : TEXCOORD1;
            float3 worldNormal : TEXCOORD2;
        };

        struct FragmentOutput
        {
            float4 gBuf0 : SV_TARGET0;
            float4 gBuf1 : SV_TARGET1;
            float4 gBuf2 : SV_TARGET2;
            float4 gBuf3 : SV_TARGET3;
        };

        sampler2D _MainTex;
        float4 _MainTex_ST;

        fixed4 _Diffuse;
        fixed4 _Specular;
        float _Gloss;

        v2f vert (appdata v)
        {
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
			o.worldNormal = UnityObjectToWorldNormal(v.normal);
			return o;
        }

        FragmentOutput frag (v2f i) : SV_Target
        {
            FragmentOutput o;
			fixed3 color = tex2D(_MainTex,i.uv).rgb * _Diffuse.rgb;
			o.gBuf0.rgb = color;
			o.gBuf0.a = 1;
			o.gBuf1.rgb = _Specular.rgb;
			o.gBuf1.a = _Gloss / 256.0;
			o.gBuf2 = float4(i.worldNormal * 0.5 + 0.5,1);
			#if !defined(UNITY_HDR_ON)
				color.rgb = exp2(-color.rgb);
			#endif
			o.gBuf3 = float4(color,1);
			return o;
        }
        ENDCG

        Pass
        {
            Tags { "LightMode" = "Deferred"}

            CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma exclude_renderers nomrt
			#pragma multi_compile __ UNITY_HDR_ON
            ENDCG
        }
    }
}
