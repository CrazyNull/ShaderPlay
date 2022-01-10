Shader "Custom/Hatching"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _TileFactor ("Tile Factor", Float) = 1
        _Offset("Offset",Range(0,1)) = 0

		_OutlineColor ("Outline Color", Color) = (1,1,1,1)
        _Outline("Thick of Outline",Range(0,0.1)) = 0.02
		_Factor("Factor",Range(0,1)) = 0.5
        

        _Hatch0 ("Hatch 0", 2D) = "white" { }
        _Hatch1 ("Hatch 1", 2D) = "white" { }
        _Hatch2 ("Hatch 2", 2D) = "white" { }
        _Hatch3 ("Hatch 3", 2D) = "white" { }
        _Hatch4 ("Hatch 4", 2D) = "white" { }
        _Hatch5 ("Hatch 5", 2D) = "white" { }

        _Rotate ("Hatch UV Rotate",Range(0,360)) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }

		Pass
        {
            Cull Front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            float4 _OutlineColor;
            float _Outline;
            float _Factor;

            v2f vert (appdata v)
            {
                v2f o;
		        float3 dir = normalize(v.vertex.xyz);
			    float3 dir2 = v.normal;
			    float d = dot(dir,dir2);
			    dir = dir * sign(d);
			    dir = dir * _Factor+dir2 * (1-_Factor);
                v.vertex.xyz += dir * _Outline;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _OutlineColor;
                return col;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShaderVariables.cginc"

            fixed4 _Color;
            float _TileFactor;
            float _Offset;

            sampler2D _Hatch0;
            sampler2D _Hatch1;
            sampler2D _Hatch2;
            sampler2D _Hatch3;
            sampler2D _Hatch4;
            sampler2D _Hatch5;

            struct a2v
            {
                float4 vertex: POSITION; 
                float3 normal: NORMAL;
                float4 texcoord: TEXCOORD0;
                float4 tangent: TANGENT;
            };

            struct v2f
            {
                float4 pos: SV_POSITION;
                float2 uv: TEXCOORD0;
                fixed3 hatchWeights0: TEXCOORD1;
                fixed3 hatchWeights1: TEXCOORD2;
                float3 worldPos: TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord.xy * _TileFactor;
                
                fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);

                fixed diff = max(0, dot(worldLightDir, worldNormal)) * (1 - _Offset) + _Offset;
                
                o.hatchWeights0 = fixed3(0, 0, 0);
                o.hatchWeights1 = fixed3(0, 0, 0);

                float hatchFactor = diff * 7;
                if (hatchFactor > 6)
                {

                }
                else if (hatchFactor > 5)
                {
                    o.hatchWeights0.x = hatchFactor - 5;
                }
                else if (hatchFactor > 4)
                {
                    o.hatchWeights0.x = hatchFactor - 4;
                    o.hatchWeights0.y = 1 - o.hatchWeights0.x;
                }
                else if (hatchFactor > 3)
                {
                    o.hatchWeights0.y = hatchFactor - 3;
                    o.hatchWeights0.z = 1 - o.hatchWeights0.y;
                }
                else if (hatchFactor > 2)
                {
                    o.hatchWeights0.z = hatchFactor - 2;
                    o.hatchWeights1.x = 1 - o.hatchWeights0.z;
                }
                else if (hatchFactor > 1)
                {
                    o.hatchWeights1.y = hatchFactor;
                    o.hatchWeights1.z = 1 - o.hatchWeights1.y;
                }
                else
                {
                    o.hatchWeights1.y = hatchFactor;
                    o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;
                }

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i): SV_TARGET
            {
                fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
                fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
                fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
                fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
                fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
                fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

                fixed4 whiteColor = fixed4(1, 1, 1, 1) * (1 - i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z -
                i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);

                fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                return fixed4(hatchColor.rgb * _Color.rgb * atten, 1);
            }

            ENDCG

        }
    }
    FallBack "Diffuse"
}
