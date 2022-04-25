Shader "Custom/Universal"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffuseCol ("Diffuse Color", Color) = (1,1,1,1)
        _NormalTex ("Normal", 2D) = "white" {}
	    _SpecularCol ("Specular Color", Color) = (0,0,0,0)
        _Metallic ("Metallic",Range(0,1)) = 0.5
	    _Smoothness ("Smoothness",Range(0,1)) = 0.5
        _Ior("IOR",Range(1,4)) = 1.5
	    [Toggle] _ENABLE_D ("Diffuse Enabled?", Float) = 1
        [Toggle] _ENABLE_NDF ("Specular Enabled?", Float) = 1
	    [Toggle] _ENABLE_G ("Geometric Shadow Enabled?", Float) = 1
	    [Toggle] _ENABLE_F ("Fresnel Enabled?", Float) = 1
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
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            #pragma multi_compile  _ENABLE_NDF_OFF _ENABLE_NDF_ON
            #pragma multi_compile  _ENABLE_G_OFF _ENABLE_G_ON
            #pragma multi_compile  _ENABLE_F_OFF _ENABLE_F_ON
            #pragma multi_compile  _ENABLE_D_OFF _ENABLE_D_ON

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
                float3 worldNormal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float3 worldTangent : TEXCOORD4;
                float3 worldBitangent : TEXCOORD5;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalTex;
            float4 _NormalTex_ST;
 
            fixed4 _DiffuseCol;
            fixed3 _SpecularCol;
            fixed _Smoothness;
            fixed _Metallic;
            float _Ior;


            float MixFunction(float i, float j, float x) 
            {
	            return j * x + i * (1.0 - x);
            } 
            float2 MixFunction(float2 i, float2 j, float x)
            {
	            return j * x + i * (1.0h - x);
            }   
            float3 MixFunction(float3 i, float3 j, float x)
            {
	            return j * x + i * (1.0h - x);
            }      
            float MixFunction(float4 i, float4 j, float x)
            {
	            return j * x + i * (1.0h - x);
            } 
            float sqr(float x)
            {
	            return x*x; 
            }

            fixed SchlickFresnel(fixed i) 
            {
                fixed x = clamp(1.0 - i, 0.0, 1.0);
                fixed x2 = x * x;
                return x2 * x2 * x;
            }
            float SchlickIORFresnelFunction(float ior, float LdotH) 
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                return f0 + (1 - f0) * SchlickFresnel(LdotH);
            }
            float DiffuseFresnel (float NdotL, float NdotV, float LdotH, float roughness)
            {
                float FresnelLight = SchlickFresnel(NdotL); 
                float FresnelView = SchlickFresnel(NdotV);
                float FresnelDiffuse90 = 0.5 + 2.0 * LdotH * LdotH * roughness;
                return  MixFunction(1, FresnelDiffuse90, FresnelLight) * MixFunction(1, FresnelDiffuse90, FresnelView);
            }
 

            UnityGI GetUnityGI(float3 lightColor, float3 lightDirection, float3 normalDirection,float3 viewDirection, float3 viewReflectDirection, float attenuation, float roughness, float3 worldPos)
            {
                UnityLight light;
                light.color = lightColor;
                light.dir = lightDirection;
                light.ndotl = max(0.0h,dot( normalDirection, lightDirection));
                UnityGIInput d;
                d.light = light;
                d.worldPos = worldPos;
                d.worldViewDir = viewDirection;
                d.atten = attenuation;
                d.ambient = 0.0h;
                d.boxMax[0] = unity_SpecCube0_BoxMax;
                d.boxMin[0] = unity_SpecCube0_BoxMin;
                d.probePosition[0] = unity_SpecCube0_ProbePosition;
                d.probeHDR[0] = unity_SpecCube0_HDR;
                d.boxMax[1] = unity_SpecCube1_BoxMax;
                d.boxMin[1] = unity_SpecCube1_BoxMin;
                d.probePosition[1] = unity_SpecCube1_ProbePosition;
                d.probeHDR[1] = unity_SpecCube1_HDR;
                Unity_GlossyEnvironmentData ugls_en_data;
                ugls_en_data.roughness = roughness;
                ugls_en_data.reflUVW = viewReflectDirection;
                UnityGI gi = UnityGlobalIllumination(d, 1.0h, normalDirection, ugls_en_data );
                return gi;
            }


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.worldTangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.worldBitangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
	            float3 wolrdLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz,_WorldSpaceLightPos0.w));
                float3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 worldHalfDir = normalize(wolrdLightDir + worldViewDir);
                float3 worldViewReflectDir = normalize(reflect(-worldViewDir,worldNormal));

                fixed NdotL  = dot(worldNormal,wolrdLightDir);
                fixed NdotV  = dot(worldNormal,worldViewDir);
                fixed NdotH  = dot(worldNormal,worldHalfDir);
                fixed VdotH  = dot(worldViewDir,worldHalfDir);
                fixed LdotH  = dot(wolrdLightDir,worldHalfDir);

                float attenuation = LIGHT_ATTENUATION(i);
                float3 attenColor = attenuation * _LightColor0.rgb;

                //间接光照
                UnityGI gi = GetUnityGI(_LightColor0.rgb, wolrdLightDir, worldNormal, worldViewDir, worldViewReflectDir, attenuation, 1 - _Smoothness, i.worldPos.xyz);
                float3 indirectDiffuse = gi.indirect.diffuse.rgb ;
	            float3 indirectSpecular = gi.indirect.specular.rgb;

                //环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;

                //纹理
                fixed4 texCol = tex2D(_MainTex, i.uv);

                //高光
	            fixed3 specColor = lerp(_SpecularCol, _DiffuseCol, _Metallic * 0.5);

                //漫反射
                float3 diffColor = (_DiffuseCol.rgb + ambient) * texCol.rgb * (1.0 - _Metallic);
#ifdef _ENABLE_D_OFF
 	diffColor = fixed3(0,0,0);
#endif
                //微表面法线分布
                float smoothnessSqr = _Smoothness * _Smoothness;
                float NdotHSqr = NdotH * NdotH;
                float SpecularDistribution = max(0.000001, (3.1415926535 * smoothnessSqr * NdotHSqr * NdotHSqr)) * exp((NdotHSqr - 1) / (smoothnessSqr * NdotHSqr));
#ifdef _ENABLE_NDF_OFF
 	specColor  = fixed3(0,0,0);
#endif
                //微表面遮挡
                float c = 0.797884560802865;
                float k = _Smoothness * _Smoothness * c;
                float gH = NdotV * k + (1 - k);
                float Gs = (gH * gH * NdotL);
#ifdef _ENABLE_G_OFF
 	 Gs = 1;
#endif
                //菲涅尔
                float Fresnel = SchlickIORFresnelFunction(_Ior, LdotH);
#ifdef _ENABLE_F_OFF
 	 Fresnel = 1;
#endif

                diffColor = diffColor * max(0,NdotL * 0.5 + 0.5) * attenColor;
	            diffColor *= DiffuseFresnel(NdotL, NdotV, LdotH, _Smoothness);
                diffColor += indirectDiffuse;

	            fixed3 specularity = ((specColor * SpecularDistribution) * (specColor * Fresnel) * (specColor * Gs)) / (4 * (NdotL * NdotV));

                fixed3 col = diffColor + specularity + indirectSpecular;
   
                UNITY_APPLY_FOG(i.fogCoord, col);
                return fixed4(col,_DiffuseCol.a * texCol.a);
            }
            ENDCG
        }
    }
    FallBack "Legacy Shaders/Diffuse"
}
