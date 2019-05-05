// Fast Subsurface Scattering in Unity
Shader "XHShaderLab/FastSubSurfaceScatteringShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		_Distortion("SSSDistortion",Range(0,2)) = 1
		_Scale("SSSScale",Range(0,10)) = 1
		_Power("SSSPower",Range(0,10)) = 1
    }
    SubShader
    {

        CGPROGRAM
        #pragma surface surf StandardTranslucent fullforwardshadows
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
		float _Distortion;
		float _Scale;
		float _Power;

		#include "UnityPBSLighting.cginc"
		inline fixed4 LightingStandardTranslucent(SurfaceOutputStandard s, fixed3 viewDir, UnityGI gi)
		{
		 // Original colour
		 fixed4 pbr = LightingStandard(s, viewDir, gi);
 
		 // Calculate intensity of backlight (light translucent)
		 float3 L = gi.light.dir;
		 float3 V = viewDir;
		 float3 N = s.Normal;
		 float3 H = normalize(L + N * _Distortion);
		 float I = pow(saturate(dot(V, -H)), _Power) * _Scale; // 背面光散射

		 pbr.rgb = pbr.rgb + gi.light.color * I;
 
		 return pbr;
		}
 
		void LightingStandardTranslucent_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
		{
		 LightingStandard_GI(s, data, gi); 
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
