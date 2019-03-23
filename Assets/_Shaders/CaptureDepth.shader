Shader "XHShaderLab/CaptureDepth"
{
    Properties
    {
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

			#include "UnityCG.cginc"

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 depth: TEXCOORD0;
			};
		
			v2f vert (appdata_base v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.depth = o.vertex.zw ;
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
			    return float4(0,1,0,1);
			    float depth = i.depth.x/i.depth.y;
				return float4(depth,0,0,1);//EncodeFloatRGBA(depth);
			}
			ENDCG
		}
    }
}
