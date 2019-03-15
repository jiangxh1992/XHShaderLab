// 环境光贴图
Shader "XHShaderLab/EnvironmentMap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

		_LightColor ("LightColor", Color) = (1,1,1,1) // 太阳光颜色
		_Kd ("Kd", Range(0,1)) = 1.0  // 漫反射系数
		_Ks("Ks",Range(0,1)) = 1.0    // 镜面反射系数

		_GlobalAmbient("GlobalAmbient", Color) = (1,1,1,1) // 环境光颜色
		_Ka("Ka", Range(0,1)) = 1.0   // 环境光系数

		_AlphaScale("AlphaScale",Range(0,1)) = 1 // 透明度
		_ReflectColor("ReflectColor",Color) = (1,1,1,1) // 反射颜色
		_ReflectScale("ReflectScale",Range(0,1)) = 0.5 // 反射系数
		_Cubemap("CubeMap",Cube) = "_Skybox"{}
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent" "LightMode"="ForwardBase"}
        //LOD 100
		ZWrite Off
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
				float4 reflectDir : TEXCOORD2;
				float4 N : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float4 _LightColor;
			float _Kd;
			float4 _GlobalAmbient;
			float _Ka;

			float _AlphaScale;
			samplerCUBE _Cubemap;
			float4 _ReflectColor;
			float _ReflectScale;

            v2f vert (appdata v)
            {
                v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				// uv坐标
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				// 世界坐标法线
				float3 N = normalize(mul(v.normal, (float3x3)unity_ObjectToWorld));
				o.N = float4(N,0);
				// 主光位置
				o.lightPos = _WorldSpaceLightPos0;
				// 反射方向
				float3 worldPosition = mul(v.vertex, (float3x3)unity_ObjectToWorld);
				float3 V = normalize(_WorldSpaceCameraPos - worldPosition);
				o.reflectDir = float4(reflect(V, N),0);
				
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
				float3 L = normalize(i.lightPos.xyz);
				float3 N = i.N.xyz;
				float nl = max(dot(N,L),0);
				float3 diffuse = _Kd * _LightColor.rgb * nl;

				// 反射颜色
				float3 reflection = texCUBE(_Cubemap, i.reflectDir.xyz).rgb * _ReflectColor.rgb;
				albedo.xyz = lerp(albedo.xyz,reflection,_ReflectScale);

				Color.rgb = albedo * (diffuse + ambient);

				Color.a = _AlphaScale;

				return Color;
            }
            ENDCG
        }
    }
}
