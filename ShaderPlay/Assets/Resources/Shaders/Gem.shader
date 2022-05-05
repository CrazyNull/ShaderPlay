Shader "Custom/Gem"
{
    Properties
    {
        _Color ("Color",Color) = (1,1,1,1)
        _SpecularColor  ("Specular Color",Color) = (1,1,1,1)
        _Speculargloss ("Specular Gloss",Range(0,20)) = 0.5
        [NoScaleOffset] _CubeTex ("Cube Texture", Cube) = "" {}
        _Ior("Ior",Range(0,5)) = 1.5

	    [Toggle] _ENABLE_SHARPEDGE ("Sharp Edge Enabled?", Float) = 0
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }
        LOD 100

        CGINCLUDE
            #include "UnityCG.cginc"
            #pragma multi_compile _ENABLE_SHARPEDGE_OFF _ENABLE_SHARPEDGE_ON

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
                #ifdef _ENABLE_SHARPEDGE_OFF
                float3 worldNormal : TEXCOORD2;
                #endif
                float3 worldPos : TEXCOORD3;
            };

            fixed4 _Color;
            fixed4 _SpecularColor;
            float _Speculargloss;
            samplerCUBE _CubeTex;
            float _Ior;

            float SchlickIORFresnelFunction(float ior, float LdotH) 
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                float x = clamp(1.0 - LdotH, 0.0, 1.0);
                float x2 = x * x;
                x = x2 * x2 * x;
                return f0 + (1 - f0) * x;
            }

            v2f vert (appdata  v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                #ifdef _ENABLE_SHARPEDGE_OFF
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                #endif
                o.worldPos =  mul(unity_ObjectToWorld,v.vertex);
                return o;
            }

            fixed4 frag1 (v2f i) : SV_Target
            {
                #ifdef _ENABLE_SHARPEDGE_OFF
                fixed3 worldNormal = normalize(i.worldNormal);
                #endif

                #ifdef _ENABLE_SHARPEDGE_ON
                fixed3 worldNormal = normalize(cross(ddy(i.worldPos),ddx(i.worldPos)));
                #endif

	            fixed3 worldLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz,_WorldSpaceLightPos0.w));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
                fixed3 worldReflectDir = normalize(reflect(-worldViewDir,worldNormal));

                fixed3 ref = texCUBE(_CubeTex,worldReflectDir) * _Color;

                fixed3 specular = pow(dot(worldViewDir,worldHalfDir), _Speculargloss) * _SpecularColor;

                return fixed4(ref + specular, 1.0f);
            }

            fixed4 frag2 (v2f i) : SV_Target
            {
                #ifdef _ENABLE_SHARPEDGE_OFF
                fixed3 worldNormal = normalize(i.worldNormal);
                #endif

                #ifdef _ENABLE_SHARPEDGE_ON
                fixed3 worldNormal = normalize(cross(ddy(i.worldPos),ddx(i.worldPos)));
                #endif
	            fixed3 worldLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                fixed3 worldRefractDir = refract(-worldViewDir,worldNormal,_Ior);
                fixed3 refract = texCUBE(_CubeTex,worldRefractDir) * _Color;
                
                return fixed4(refract,1.0f);
            }

        ENDCG

        Pass
        {
            Cull Front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag2
            ENDCG 
        }

        Pass
        {
            Cull Back
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag1
            ENDCG
        }

    }

    FallBack "Legacy Shaders/Diffuse"
}
