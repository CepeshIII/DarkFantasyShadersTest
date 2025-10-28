
// Slight modification of kuwahara to soften the highly aliased zones, by Eideren
// Use this code in accordance to kuwahara's license !

Shader "ImageFilter/Kuwahara-Mod"
{
	Properties
	{
		radius("Radius", int) = 4
		filterIntensity("Filter Intensity", float) = 10
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
			
			#define TexChannel0 _GrabTexture
			#define TexChannel0_TexelSize _GrabTexture_TexelSize
			
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
			
			sampler2D _GrabTexture;
			float4 _GrabTexture_TexelSize;
			int radius;
			int filterDelta;
			float filterIntensity;
			
			v2f vert (vIn v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.screenPos = o.vertex;
				
				return o;
			}
			
			
			void mainImage( out float4 fragColor, in float2 fragCoord ) {
				float2 TexChannel0_size = _ScreenParams.xy;
				float2 uv = fragCoord.xy / TexChannel0_size;
				//const int radius = 4;
				float n = float((radius + 1) * (radius + 1));
				
				float3 m[4];
				float3 s[4];
				for (int k = 0; k < 4; ++k) {
					m[k] = (0.0);
					s[k] = (0.0);
				}
				
				for (int j = -radius; j <= 0; ++j)  {
					for (int i = -radius; i <= 0; ++i)  {
						float3 c = tex2D(TexChannel0, uv + float2(i,j) / TexChannel0_size).rgb;
						m[0] += c;
						s[0] += c * c;
					}
				}
				
				for (int j = -radius; j <= 0; ++j)  {
					for (int i = 0; i <= radius; ++i)  {
						float3 c = tex2D(TexChannel0, uv + float2(i,j) / TexChannel0_size).rgb;
						m[1] += c;
						s[1] += c * c;
					}
				}
				
				for (int j = 0; j <= radius; ++j)  {
					for (int i = 0; i <= radius; ++i)  {
						float3 c = tex2D(TexChannel0, uv + float2(i,j) / TexChannel0_size).rgb;
						m[2] += c;
						s[2] += c * c;
					}
				}
				
				for (int j = 0; j <= radius; ++j)  {
					for (int i = -radius; i <= 0; ++i)  {
						float3 c = tex2D(TexChannel0, uv + float2(i,j) / TexChannel0_size).rgb;
						m[3] += c;
						s[3] += c * c;
					}
				}
				
				fragColor = 0;
				float min_sigma2 = 1e+2;
				float3 median = 0;
				for (int k = 0; k < 4; ++k) {
					m[k] /= n;
					s[k] = abs(s[k] / n - m[k] * m[k]);
					
					float sigma2 = s[k].r + s[k].g + s[k].b;
					median += m[k] / 4;
					if (sigma2 < min_sigma2) {
						min_sigma2 = sigma2;
						fragColor = float4(m[k], 1.0);
					}
				}
                
                UNITY_BRANCH
				if(filterIntensity > 0.5)
					fragColor.rgb = lerp(fragColor.rgb, tex2D(TexChannel0, uv).rgb, saturate(fwidth(fragColor.rgb)*filterIntensity));
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
				mainImage(col, sceneUVs * _ScreenParams.xy);
				
				return col;
			}
			ENDCG
		}
	}
}

