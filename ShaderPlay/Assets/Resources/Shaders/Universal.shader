Shader "Custom/Universal"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffuseCol ("Diffuse Color", Color) = (1,1,1,1)
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
 
            fixed4 _DiffuseCol;
            fixed3 _SpecularCol;
            fixed _Smoothness;
            fixed _Metallic;
            float _Ior;

            float MixFunction(float i, float j, float x) 
            {
                return j * x + i * (1.0 - x);
            }

            fixed SchlickFresnel(fixed i) 
            {
                fixed x = clamp(1.0 - i, 0.0, 1.0);
                fixed x2 = x * x;
                return x2 * x2 * x;
            }

            fixed3 SchlickFresnelFunction(fixed3 SpecularColor, fixed LdotH) 
            {
                return SpecularColor + (1 - SpecularColor) * SchlickFresnel(LdotH);
            }

            float SchlickIORFresnelFunction(float ior, float LdotH) 
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                return f0 + (1 - f0) * SchlickFresnel(LdotH);
            }

            float3 FresnelLerp (float3 x, float3 y, float d)
            {
	            float t = SchlickFresnel(d);	
	            return lerp (x, y, t);
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

                UnityGI gi = GetUnityGI(_LightColor0.rgb, wolrdLightDir, worldNormal, worldViewDir, worldViewReflectDir, attenuation, 1 - _Smoothness, i.worldPos.xyz);
                float3 indirectDiffuse = gi.indirect.diffuse.rgb ;
	            float3 indirectSpecular = gi.indirect.specular.rgb;


                //漫反射
                fixed4 texCol = tex2D(_MainTex, i.uv);
                fixed lambert = max(0,dot(worldNormal,wolrdLightDir)) * 0.5 + 0.5;
                fixed3 diffColor = _DiffuseCol.rgb * texCol.rgb * lambert * attenColor + indirectDiffuse;
                diffColor = diffColor * (1.0 - _Metallic);
#ifdef _ENABLE_D_OFF 
 	 diffColor = fixed3(0,0,0);
#endif

                //微表面法线分布
                float smoothnessSqr = _Smoothness * _Smoothness;
                float NdotHSqr = NdotH * NdotH;
                float specPower = max(0.000001, (3.1415926535 * smoothnessSqr * NdotHSqr * NdotHSqr)) * exp((NdotHSqr - 1) / (smoothnessSqr * NdotHSqr));
                fixed3 specColor = _SpecularCol * specPower;
	            specColor = lerp(specColor, diffColor, _Metallic * 0.5);
#ifdef _ENABLE_NDF_OFF
 	specColor  = fixed3(0,0,0);
#endif

                //微表面遮挡
                float Gs = pow(NdotL * NdotV, 0.5);
#ifdef _ENABLE_G_OFF
 	 Gs = 0;
#endif

                //菲涅尔
                float Fresnel = SchlickIORFresnelFunction(_Ior, LdotH);
#ifdef _ENABLE_F_OFF
 	 Fresnel = 0;
#endif


                specColor = (Gs * _LightColor0 + indirectSpecular) * specColor;
                fixed3 col = diffColor + specColor;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                col += ambient;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return fixed4(col,_DiffuseCol.a * texCol.a);
            }
            ENDCG
        }
    }
    FallBack "Legacy Shaders/Diffuse"
}
