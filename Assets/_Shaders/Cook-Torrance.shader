// 用来简单展示真实的模型
Shader "XHShaderLab/Cook-Toorance"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_LightColor ("LightColor", Color) = (1,1,1,1) // 太阳光颜色

		/* 表面漫反射 */
		_Kd ("Kd", Range(0,1)) = 1.0  // 漫反射系数
		_Ks("Ks",Range(0,1)) = 1.0    // 镜面反射系数
		_Wrap("Wrap",Range(0,1)) = 1.0

		/* 环境光分量 */
		_GlobalAmbient("GlobalAmbient", Color) = (1,1,1,1) // 环境光颜色
		_Ka("Ka", Range(0,1)) = 1.0   // 环境光系数

		/* 不同经典光照模型中的高光反射 */
		_Roughness("Roughness",Range(0,1)) = 0.1   // 粗糙度
		_Fresnel("Fresnel",Range(0,1)) = 0.8        // 菲涅尔系数
		_Shininess("Shininess", Range(0,100)) = 50   // phong模型中镜面反射的高光系数
		[Enum(None,0,CookTorrance,1,Phong,2,BlinnPhong,3,BankBRDF,4)]_LightModel("LightModel",Int) = 1

		/* 次表面散射 */
		_Distortion("SSSDistortion",Range(0,2)) = 1
		_Scale("SSSScale",Range(0,10)) = 1
		_Power("SSSPower",Range(0,10)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"}
        //LOD 100
		//ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
			Cull Back
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#include "Lighting.cginc"
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
            };

            struct v2f
            {
			    float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
				float4 lightPos : TEXCOORD1;
				float4 eyePosition : TEXCOORD2;
				float4 N : TEXCOORD3;
				float4 position : TEXCOORD4;
				float4 worldPos : TEXCOORD5;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float4 _LightColor;
			float _Kd;
			float _Ks;
			float _Wrap;
			float4 _GlobalAmbient;
			float _Ka;
			float _Roughness;
			float _Fresnel;
			float _Shininess;

			float _LightModel;

			float _Distortion;
			float _Scale;
			float _Power;

			sampler2D _LightDepthTex;   // 光源深度图
            float4x4 _LightProjection;  // 光源变换矩阵

#define PI 3.1415926

            v2f vert (appdata v)
            {
                v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// 顶点世界坐标
                o.position = mul(v.vertex.xyz, (float3x3)unity_ObjectToWorld).xyzz;
				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.worldPos.w = 1;
				// uv坐标
                o.uv = ComputeScreenPos(v.vertex);//TRANSFORM_TEX(v.uv, _MainTex);
				// 世界坐标法线
				float3 N = normalize(mul(v.normal, (float3x3)unity_ObjectToWorld));
				o.N = float4(N,0);
				// 主光位置
				o.lightPos = _WorldSpaceLightPos0; // ObjSpaceLightDir(v.vertex)
				// 相机位置
				o.eyePosition = _WorldSpaceCameraPos.xyzz; // ObjSpaceViewDir(v.vertex);
				
                return o;
            }

			// GGX法线分布函数
			float DistributionGGX(float3 N, float3 H, float a)
			{
				float a2 = a * a;
				float NdotH = max(dot(N, H), 0.0);
				float NdotH2 = NdotH * NdotH;

				float nom = a2;
				float denom = (NdotH2 * (a2 - 1.0) + 1.0);
				denom = PI * denom * denom;

				return nom / denom;
			}

            fixed4 frag (v2f i) : SV_Target
            {
			    float3 L;
				if(i.lightPos.w == 0)
				    L = normalize(i.lightPos.xyz); // 平行光
				else
				    L = normalize(i.lightPos.xyz - i.position.xyz);
				float3 N = i.N.xyz;
				float nl = max(dot(N,L),0);
			    float3 V = normalize(i.eyePosition.xyz - i.position.xyz);
				float3 H = normalize(L + V); // 半角向量
				float3 R = normalize(2 * nl * N - L); // 反射光向量

				
				float3 T = normalize(cross(N,V)); // 顶点切线向量
				float nh = max(dot(N,H),0);
				float nv = max(dot(N,V),0);
				float vh = max(dot(V,H),0);
				bool front = nl > 0;//(nv > 0) && (nl > 0); // 光源模型正面


			    float4 Color;

			    // 贴图颜色
                float4 albedo = tex2D(_MainTex, i.uv);
				//clip(albedo.w - 0.5f);
				
				// 环境光
				float3 ambient = _Ka * _GlobalAmbient.rgb;

				// 漫反射光
				float wrap_nl = (nl + _Wrap) / (1 + _Wrap);
				float3 diffuse = _Kd * _LightColor.rgb * wrap_nl;
				
				// 1. Cook-Torrance镜面反射
				float3 specular = 0;
				if(front)
				{
					float temp = (nh*nh-1) / (_Roughness*_Roughness * nh*nh);
					float D = (exp(temp)) / (pow(_Roughness,2)*pow(nh,4.0)); // 1.1 beckmann函数，法线分布函数，估算在受到表面粗糙度的影响下，取向方向与中间向量一致的微平面的数量（半角向量H）
					float DGGX = DistributionGGX(N, H, _Roughness);

					float a = (2*nh*nv)/vh;
					float b = (2*nh*nl)/vh;
					float G = min(a,b);
					G = min(1,G); // 1.2 几何衰减系数，衡量微表面自身屏蔽光强的影响

					float F = _Fresnel + (1-_Fresnel)*pow(1-vh,5.0); // 1.3 fresnel反射系数,描述反射光强比率

					float rs = (F * G * D) / (nv * nl);
					specular = _Ks * rs * _LightColor.rgb * nl;
				}

				// 2. phong模型镜面反射
				float vr = max(dot(V,R),0);
				float specular_phong = _Ks * _LightColor * pow(vr,_Shininess);

				// 3. blinn-phong模型镜面反射
				float specular_blinnPhong = _Ks * _LightColor * pow(nh,_Shininess);

				// 4. Bank BRDF经验模型镜面反射
				float3 specular_bankBRDF = 0;
				if(front)
				{
					float a = dot(L,T);
					float b = dot(V,T);
					float c = sqrt(1-pow(a,2.0)) * sqrt(1-pow(b,2.0)) - a*b; // Bank BRDF系数
					float brdf = _Ks * pow(c, _Shininess);
					specular_bankBRDF = brdf * _LightColor * nl;
				}
				
				// 次表面散射
				float I = 1.0;
				float3 H2 = normalize(L - N * _Distortion);

				if(front)
				{
				    I = pow(saturate(dot(V, -H2)), _Power) * _Scale;
				}
				else
				{
				    float H2Back = dot(V,-(L + N));
				    float wrap_lv = (H2Back + _Wrap) / (1 + _Wrap);
				    I = pow(saturate(H2Back), _Power) * _Scale;
				}

				// 分量合成
				if(_LightModel == 1)
                    Color.rgb = albedo * (diffuse + ambient*I + specular);
				else if(_LightModel == 2)
				    Color.rgb = albedo * (diffuse + ambient*I + specular_phong);
			    else if(_LightModel == 3)
				    Color.rgb = albedo * (diffuse + ambient*I + specular_blinnPhong);
				else if(_LightModel == 4)
					Color.rgb = albedo * (diffuse + ambient*I + specular_bankBRDF);
				else
				    Color.rgb = albedo * (diffuse + ambient*I);

				Color.a = 1.0;

				return Color; //float4(I,I,I,1)
            }
            ENDCG
        }
		
    }
}
