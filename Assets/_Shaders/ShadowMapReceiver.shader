// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
Shader "Shadow/ShadowMapReceiver"
{
    Properties
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_ShadowCutOff("ShadowCutOff",Range(-1,1)) = 0
    }

	SubShader
	{
		Tags
		{
		 	"RenderType"="Opaque"
	 	}
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

            uniform half4 _MainTex_TexelSize;
            sampler2D _MainTex;
			float4 _MainTex_ST;
			float _ShadowCutOff;

            sampler2D _LightDepthTex;   // 光源深度图
            float4x4 _LightProjection;  // 光源变换矩阵

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv: TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 worldPos: TEXCOORD0;
				float2 uv:TEXCOORD1;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float4 worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.worldPos.xyz = worldPos.xyz ;
				o.worldPos.w = 1 ;
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				// 光源空间下的坐标
				float4 lightClipPos = mul(_LightProjection , i.worldPos);
			    lightClipPos.xyz = lightClipPos.xyz / lightClipPos.w;

				// 深度值
				float3 pos = lightClipPos * 0.5 + 0.5 ;
				float4 depthRGBA = tex2D(_LightDepthTex,pos.xy);

				float depth = depthRGBA.r;//DecodeFloatRGBA(depthRGBA);

				// 阴影
				if(lightClipPos.z + _ShadowCutOff > depth  )
				{
					return float4(0,0,0,1);
				}
				//else
				//return float4(1,1,1,1);

				// color
			    float4 color = tex2D(_MainTex,i.uv);
				return color;

			}
			ENDCG
		}
	}

	FallBack "Diffuse"
}
