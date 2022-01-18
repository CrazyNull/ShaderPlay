Shader "Custom/GroundGlass"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _DumpTex ("Dump Texture",2D) = "white" {}
        _DumpScale ("Dump Scale",Range(0,20)) = 1.0
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

                float3	TtoV0 : TEXCOORD3;
				float3	TtoV1 : TEXCOORD4;
				float3	TtoV2 : TEXCOORD5;
            };

            fixed4 _Color;

            sampler2D _BackgroundTexture;
            float4 _BackgroundTexture_ST;

            sampler2D _DumpTex;
            float4 _DumpTex_ST;

            float _DumpScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_DumpTex);
                o.grabPos = ComputeGrabScreenPos(o.vertex);

                TANGENT_SPACE_ROTATION;

                o.TtoV0 = normalize(mul(rotation, unity_WorldToObject[0].xyz));
				o.TtoV1 = normalize(mul(rotation, unity_WorldToObject[1].xyz));
				o.TtoV2 = normalize(mul(rotation, unity_WorldToObject[2].xyz));

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 dumpuv = float2(i.uv.x * _DumpTex_ST.x + _DumpTex_ST.z , i.uv.y * _DumpTex_ST.y + _DumpTex_ST.w);
                float3 tangentNormal = UnpackNormal(tex2D(_DumpTex, dumpuv));
                tangentNormal.xy *= _DumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                float3x3 TtoVMatrix = float3x3(i.TtoV0.xyz,i.TtoV1.xyz,i.TtoV2.xyz);
                float3 viewNormal = mul(TtoVMatrix,tangentNormal);
                i.grabPos.xyz += viewNormal.yxz;
                fixed4 grabcol = tex2Dproj(_BackgroundTexture,i.grabPos);

                fixed4 col = _Color * grabcol;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
