Shader "Custom/Gem"
{
    Properties
    {
        _Color("Color",Color)=(1,1,1,1)
        _ReflectionStrength("Reflection Strength",Range(0.0,2.0))=1.0
        [NoScaleOffset] _RefractTex ("Refraction Texture", Cube) = "" {}
        _Ior("Ior",Range(1,5)) = 1.5

    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }
        LOD 100

        CGINCLUDE
            #include "UnityCG.cginc"

            float SchlickIORFresnelFunction(float ior, float LdotH) 
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                float x = clamp(1.0 - LdotH, 0.0, 1.0);
                float x2 = x * x;
                x = x2 * x2 * x;
                return f0 + (1 - f0) * x;
            }

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };

            fixed4 _Color;
            samplerCUBE _RefractTex;
            half _ReflectionStrength;
            float _Ior;

            v2f vert (appdata  v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag1 (v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
	            fixed3 worldLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz,_WorldSpaceLightPos0.w));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
                fixed3 worldReflectDir = -reflect(worldViewDir,worldNormal);

                fixed3 refraction = texCUBE(_RefractTex,worldReflectDir);// * _Color;
                // half4 reflection = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0 , worldReflectDir);
                // reflection.rgb = DecodeHDR(reflection,unity_SpecCube0_HDR);

                return fixed4(refraction, 1.0f);
            }

            fixed4 frag2 (v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
	            fixed3 worldLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);

                fixed3 worldReflectDir = -reflect(worldViewDir,worldNormal);

                fixed LdotH = dot(worldLightDir,worldHalfDir);


                fixed3 refraction = texCUBE(_RefractTex,worldReflectDir);// * _Color;
                // half4 reflection = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0,worldReflectDir);
                // reflection.rgb = DecodeHDR(reflection,unity_SpecCube0_HDR);

                // float fresnel = SchlickIORFresnelFunction(_Ior,LdotH);
                // fixed3 reflection2 = reflection * _ReflectionStrength * fresnel;
                
                return fixed4(refraction,1.0f);
            }

        ENDCG

        Pass
        {
            Cull  Front
            ZWrite Off 
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag1
            ENDCG
        }

        Pass
        {
            ZWrite On
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag2
            ENDCG 
        }

    }

    FallBack "Legacy Shaders/Diffuse"
}
