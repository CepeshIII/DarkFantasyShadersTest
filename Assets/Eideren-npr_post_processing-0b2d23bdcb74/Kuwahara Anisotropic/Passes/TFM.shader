
// Anisotropic Kuwahara Filtering on the GPU
// www.kyprianidis.com
// Paper : http://www.kyprianidis.com/p/pg2009/jkyprian-pg2009.pdf
// Preview App' : https://code.google.com/archive/p/gpuakf/downloads
// Code : https://code.google.com/archive/p/gpuakf/source/default/source
// Use this code in accordance to the license holder's license !

// this shader is an extracted pass used inside KuwaharaAKF1

Shader "ImageFilter/Passes/KuwaTFM"
{
	Properties
	{
		
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Overlay"
			"Queue"="Overlay"
			
		}
		ZWrite Off
		GrabPass{ }
		
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			
			
			struct vIn
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
			
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD5;
				
			};

			#define src _GrabTexture
			#define textureSize2D(x,y) _GrabTexture_TexelSize.zw
			#define texture2D tex2D
			
			sampler2D _GrabTexture;
			float4 _GrabTexture_TexelSize;
			
			
			v2f vert (vIn v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.screenPos = o.vertex;
				
				return o;
			}
			
			// by Jan Eric Kyprianidis <www.kyprianidis.com>
			//uniform sampler2D src;
			
			void main ( out float4 fragColor, in float2 fragCoord ) {
				float2 uv = fragCoord.xy / (textureSize2D(src, 0));
				float3 g = texture2D(src, uv).xyz;
				
				float lambda1 = 0.5 * (g.y + g.x +
				sqrt(g.y*g.y - 2.0*g.x*g.y + g.x*g.x + 4.0*g.z*g.z));
				float lambda2 = 0.5 * (g.y + g.x -
				sqrt(g.y*g.y - 2.0*g.x*g.y + g.x*g.x + 4.0*g.z*g.z));
				
				float2 v = float2(lambda1 - g.x, -g.z);
				float2 t;
				if (length(v) > 0.0) {
					t = normalize(v);
					} else {
					t = float2(0.0, 1.0);
				}
				
				float phi = atan2(t.y, t.x);
				
				float A = (lambda1 + lambda2 > 0.0)?
				(lambda1 - lambda2) / (lambda1 + lambda2) : 0.0;
				
				fragColor = float4(t, phi, A);
			}
			
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = 0;
				i.screenPos = float4( i.screenPos.xy / i.screenPos.w, 0, 0 );
				i.screenPos.y *= _ProjectionParams.x;
				#if UNITY_UV_STARTS_AT_TOP
				float grabSign = -_ProjectionParams.x;
				#else
				float grabSign = _ProjectionParams.x;
				#endif
				float2 sceneUVs = float2(1,grabSign)*i.screenPos.xy*0.5+0.5;
				main(col, sceneUVs * _ScreenParams.xy);
				
				return col;
			}
			ENDCG
		}
	}
}

