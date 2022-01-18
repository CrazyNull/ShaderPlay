Shader "Custom/GroundGlass"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _DumpTex ("Dump Texture",2D) = "white" {}
        _DumpScale ("Dump Scale",Range(0,10)) = 0
        _RefractRatio("Refract Ratio",Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType"="Opaque" }
        LOD 100

        GrabPass{ "_BackgroundTexture" }

        Pass
        {
            Tags { "LightMode" = "ForwardBase"}

            //Blend SrcAlpha OneMinusSrcAlpha
            //ZWrite Off

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
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 grabPos : TEXCOORD2;

                float3	TtoW0 : TEXCOORD3;
				float3	TtoW1 : TEXCOORD4;
				float3	TtoW2 : TEXCOORD5;

                float3 worldNormal : TEXCOORD6;
                float3 worldViewDir : TEXCOORD7;
            };

            fixed4 _Color;

            sampler2D _BackgroundTexture;
            float4 _BackgroundTexture_ST;

            sampler2D _DumpTex;
            float4 _DumpTex_ST;

            float _RefractRatio;
            float _DumpScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_DumpTex);
                o.grabPos = ComputeGrabScreenPos(o.vertex);

                TANGENT_SPACE_ROTATION;

                o.TtoW0 = normalize(mul(rotation, unity_WorldToObject[0].xyz));
				o.TtoW1 = normalize(mul(rotation, unity_WorldToObject[1].xyz));
				o.TtoW2 = normalize(mul(rotation, unity_WorldToObject[2].xyz));

                o.worldNormal = mul(unity_ObjectToWorld,v.normal);
                float3 worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.worldViewDir = UnityWorldSpaceViewDir(worldPos);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 dumpuv = float2(i.uv.x * _DumpTex_ST.x + _DumpTex_ST.z , i.uv.y * _DumpTex_ST.y + _DumpTex_ST.w);
                float3 tangentNormal = UnpackNormal(tex2D(_DumpTex, dumpuv));
                float3x3 TtoWMatrix = float3x3(i.TtoW0.xyz,i.TtoW1.xyz,i.TtoW2.xyz);
                
                float3 worldNormal = mul(TtoWMatrix,tangentNormal) * _DumpScale + i.worldNormal;
                worldNormal = normalize(worldNormal);

                float3 worldRefr = refract(-normalize(i.worldViewDir), normalize(worldNormal),_RefractRatio);
                worldRefr = normalize(worldRefr);

                i.grabPos.xyz += worldRefr.xyz;

                fixed4 grabcol = tex2Dproj(_BackgroundTexture,i.grabPos);

                fixed4 col = _Color * grabcol;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
