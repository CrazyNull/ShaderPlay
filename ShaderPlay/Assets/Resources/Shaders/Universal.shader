Shader "Custom/Universal"
{
    Properties
    {
        _AlbedoTex ("Albedo Texture", 2D) = "white" {}
        _Albedo ("Albedo", Color) = (1,1,1,1)

        _NormalTex ("Normal", 2D) = "white" {}
        _NormalScale ("Normal Scale",Range(0,1)) = 1.0
        
        _Metallic ("Metallic",Range(0,1)) = 0.5
	    _Smoothness ("Smoothness",Range(0,1)) = 0.5
        _Ior("Ior",Range(1,5)) = 1.5

        _CapColor ("Cap Color",Color) = (1,1,1,1)
        _CapTex ("Cap Texture",2D) = "white" {}
        _CapIntensity("Cap Intensity",Range(0,1)) = 0
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
                float2 cap : TEXCOORD6;

                float4 T2W0 : TEXCOORD7;
				float4 T2W1 : TEXCOORD8;
				float4 T2W2 : TEXCOORD9;

                float2 normalUV : TEXCOORD10;

            };

            sampler2D _AlbedoTex;
            float4 _AlbedoTex_ST;

            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            fixed _NormalScale;

            fixed4 _Albedo;
            fixed _BaseF0;
            fixed _Smoothness;
            fixed _Metallic;
            float _Ior;

            fixed3 _CapColor;
            sampler2D _CapTex;
            float _CapIntensity;

  
            float MixFunction(float i, float j, float x) 
            {
                return j * x + i * (1.0 - x);
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

            fixed3 fresnelSchlick(float cosTheta, fixed3 F0)
            {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }

            float SchlickIORFresnelFunction(float ior, float LdotH) 
            {
                float f0 = pow(ior - 1, 2) / pow(ior + 1, 2);
                float x = clamp(1.0 - LdotH, 0.0, 1.0);
                float x2 = x * x;
                x = x2 * x2 * x;
                return f0 + (1 - f0) * x;
            }

            fixed DistributionGGX(fixed3 NdotH, fixed roughness) 
            {
                float roughnessSqr = roughness * roughness;
                float NdotHSqr = NdotH * NdotH;
                return roughnessSqr / (3.1415926535  * pow(NdotHSqr * (roughnessSqr - 1) + 1, 2));
            }

            fixed SchlickGGX(float cosTheta, fixed k) 
            {
                return cosTheta / (cosTheta * (1 - k) + k);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _AlbedoTex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.worldTangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.worldBitangent = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w);
                o.cap = mul(UNITY_MATRIX_MV,v.normal).xy * 0.5 + 0.5;


                o.normalUV = TRANSFORM_TEX(v.uv, _NormalTex);

				float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				float3 worldBiNormal = cross(o.worldNormal,worldTangent) * v.tangent.w;
				o.T2W0 = float4(worldTangent.x,worldBiNormal.x,o.worldNormal.x,o.worldPos.x);
				o.T2W1 = float4(worldTangent.y,worldBiNormal.y,o.worldNormal.y,o.worldPos.y);
				o.T2W2 = float4(worldTangent.z,worldBiNormal.z,o.worldNormal.z,o.worldPos.z);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                //法线贴图
                fixed4 normalColor = tex2D(_NormalTex,i.normalUV);
                fixed3 worldTangentNormal = UnpackNormal(normalColor);
				worldTangentNormal = normalize(half3(dot(worldTangentNormal,i.T2W0.xyz),dot(worldTangentNormal,i.T2W1.xyz),dot(worldTangentNormal,i.T2W2.xyz)));

                fixed3 worldNormal = normalize(i.worldNormal + worldTangentNormal * _NormalScale);
	            fixed3 worldLightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz,_WorldSpaceLightPos0.w));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
                fixed3 worldViewReflectDir = normalize(reflect(-worldViewDir,worldNormal));

                fixed NdotL  = dot(worldNormal,worldLightDir);
                fixed NdotV  = dot(worldNormal,worldViewDir);
                fixed NdotH  = dot(worldNormal,worldHalfDir);
                fixed VdotH  = dot(worldViewDir,worldHalfDir);
                fixed LdotH  = dot(worldLightDir,worldHalfDir);

                _Smoothness = _Smoothness * _Smoothness;

                float PI = 3.1415926535;

                //直接光照
                float attenuation = LIGHT_ATTENUATION(i);
                float3 attenColor = attenuation * _LightColor0.rgb;

                //间接光照
                UnityGI gi = GetUnityGI(_LightColor0.rgb, worldLightDir, worldNormal, worldViewDir, worldViewReflectDir, attenuation, 1 - _Smoothness, i.worldPos.xyz);
                float3 indirectDiffuse = gi.indirect.diffuse.rgb ;
	            float3 indirectSpecular = gi.indirect.specular.rgb;

                //环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;

                //纹理
                fixed4 albedoTex = tex2D(_AlbedoTex, i.uv);

                //反照率
                fixed3 albedo = _Albedo.rgb * albedoTex.rgb;

                //菲涅尔
                float F = SchlickIORFresnelFunction(_Ior, LdotH);

                //微表面法线分布
                float D = DistributionGGX(NdotH,_Smoothness);

                //微表面遮挡
                fixed kDir = pow(_Smoothness + 1,2) / 8;
                fixed ggx1 = SchlickGGX(max(0.0001,NdotL),kDir);
                fixed ggx2 = SchlickGGX(max(0.0001,NdotV),kDir);
                fixed G = ggx1 * ggx2;

                fixed3 F0 = 0.04;
                F0 = MixFunction(F0, albedo, _Metallic);
                F0 = F0 + (1 - F0) * exp2((-5.55473 * VdotH - 6.98316) * VdotH);
                fixed3 kd = (1 - F0) * (1 - _Metallic);
                fixed3 diffuse = albedo / PI * kd;
                diffuse = diffuse * attenColor * max(0.0001,NdotL * 0.5 + 0.5) + indirectDiffuse;

                fixed3 brdf = F * D * G /  (4 * (NdotL * NdotV)) * attenColor * max(0.0001,NdotL);

                fixed3 col = (diffuse + brdf) * PI + indirectSpecular;

                //Matcap
                fixed3 capCol = tex2D(_CapTex,i.cap) * (_CapIntensity * _CapIntensity) * _CapColor;
                col += capCol;

                UNITY_APPLY_FOG(i.fogCoord, col);

                return fixed4(col,_Albedo.a * albedoTex.a);
            }
            ENDCG
        }
    }
    FallBack "Legacy Shaders/Diffuse"
}
