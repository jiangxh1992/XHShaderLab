// 用来简单展示真实的模型
Shader "XHShaderLab/Grass"
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

		/* 简单透明混合 */
		_AlphaScale("AlphaScale",Range(0,1)) = 1.0 // 透明度

		/* 次表面散射 */
		_Distortion("SSSDistortion",Range(0,2)) = 1
		_Scale("SSSScale",Range(0,10)) = 1
		_Power("SSSPower",Range(0,10)) = 1

    }
    SubShader
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent" "LightMode"="ForwardBase"}
        //LOD 100
		//ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
			Cull Off
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
                float2 uv : TEXCOORD0;
				float4 lightPos : TEXCOORD1;
				float4 eyePosition : TEXCOORD2;
				float4 N : TEXCOORD3;
				float4 position : TEXCOORD4;
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
			float _AlphaScale;

			float _LightModel;

			float _Distortion;
			float _Scale;
			float _Power;

            v2f vert (appdata v)
            {
                v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// 顶点世界坐标
                o.position = mul(v.vertex.xyz, (float3x3)unity_ObjectToWorld).xyzz;
				// uv坐标
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				// 世界坐标法线
				float3 N = normalize(mul(v.normal, (float3x3)unity_ObjectToWorld));
				o.N = float4(N,0);
				// 主光位置
				o.lightPos = _WorldSpaceLightPos0; // ObjSpaceLightDir(v.vertex)
				// 相机位置
				o.eyePosition = _WorldSpaceCameraPos.xyzz; // ObjSpaceViewDir(v.vertex);
				
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
			    float4 Color;

			    // 贴图颜色
                float4 albedo = tex2D(_MainTex, i.uv);
				//clip(albedo.w - 0.5f);
				
				// 环境光
				float3 ambient = _Ka * _GlobalAmbient.rgb;

				// 漫反射光
				float3 L = normalize(i.lightPos.xyz - i.position.xyz);
				float3 N = i.N.xyz;
				float nl = max(dot(N,L),0);
				float wrap_nl = (nl + _Wrap) / (1 + _Wrap);
				float3 diffuse = _Kd * _LightColor.rgb * wrap_nl;
				
				// 1. Cook-Torrance镜面反射
				float3 specular = 0;
				float3 V = normalize(i.eyePosition.xyz - i.position.xyz);
				float3 H = normalize(L + V); // 半角向量
				float3 R = normalize(2 * nl * N - L); // 反射光向量

				float nv = dot(N,V);
				bool back = (nv > 0) && (nl > 0);
				if(back)
				{
				    float nh = dot(N,H);
					float temp = (nh*nh-1) / (_Roughness*_Roughness * nh*nh);
					float roughness = (exp(temp)) / (pow(_Roughness,2)*pow(nh,4.0)); // 粗糙度，根据beckmann函数

					float vh = dot(V,H);
					float a = (2*nh*nv)/vh;
					float b = (2*nh*nl)/vh;
					float geometric = min(a,b);
					geometric = min(1,geometric); // 几何衰减系数

					float fresnelCoe = _Fresnel + (1-_Fresnel)*pow(1-vh,5.0); // fresnel 反射系数
					float rs = (fresnelCoe*geometric*roughness) / (nv * nl);
					specular = _Ks * rs * _LightColor.rgb * nl;
				}

				// 2. phong模型镜面反射
				float vr = max(dot(V,R),0);
				float specular_phong = _Ks * _LightColor * pow(vr,_Shininess);


				// 3. blinn-phong模型镜面反射
				float nh = max(dot(N,H),0);
				float specular_blinnPhong = _Ks * _LightColor * pow(nh,_Shininess);

				// 4. Bank BRDF经验模型镜面反射
				float3 specular_bankBRDF = 0;
				if(back)
				{
				    float3 T = normalize(cross(N,V)); // 顶点切线向量
					float a = dot(L,T);
					float b = dot(V,T);
					float c = sqrt(1-pow(a,2.0)) * sqrt(1-pow(b,2.0)) - a*b; // Bank BRDF系数
					float brdf = _Ks * pow(c, _Shininess);
					specular_bankBRDF = brdf * _LightColor * nl;
				}
				
				// 此表面散射
				float3 H2 = normalize(L + N * _Distortion);
                float I = pow(saturate(dot(V, H2)), _Power) * _Scale;

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

				Color.a = _AlphaScale;

				return Color;
            }
            ENDCG
        }
    }
}
