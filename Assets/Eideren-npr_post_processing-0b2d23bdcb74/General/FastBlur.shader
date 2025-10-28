
// Fast Blur by jcant0n @ https://www.shadertoy.com/view/XssSDs
// Use this code in accordance to the license holder's license !

// could still be optimized quite a bit contrary to his name -Eideren

Shader "ImageFilter/FastBlur"
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
			
			
			v2f vert (vIn v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.screenPos = o.vertex;
				
				return o;
			}
			
			float2 Circle(float Start, float Points, float Point)
			{
				float Rad = (3.141592 * 2.0 * (1.0 / Points)) * (Point + Start);
				return float2(sin(Rad), cos(Rad));
			}
			
			void mainImage( out float4 fragColor, in float2 fragCoord )
			{
				float2 uv = fragCoord.xy / _ScreenParams.xy;
				float2 PixelOffset = 1.0 / _ScreenParams.xy;
				
				float Start = 2.0 / 14.0;
				float2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;
				
				float3 N0 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 0.0) * Scale).rgb;
				float3 N1 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 1.0) * Scale).rgb;
				float3 N2 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 2.0) * Scale).rgb;
				float3 N3 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 3.0) * Scale).rgb;
				float3 N4 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 4.0) * Scale).rgb;
				float3 N5 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 5.0) * Scale).rgb;
				float3 N6 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 6.0) * Scale).rgb;
				float3 N7 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 7.0) * Scale).rgb;
				float3 N8 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 8.0) * Scale).rgb;
				float3 N9 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 9.0) * Scale).rgb;
				float3 N10 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 10.0) * Scale).rgb;
				float3 N11 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 11.0) * Scale).rgb;
				float3 N12 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 12.0) * Scale).rgb;
				float3 N13 = tex2D(TexChannel0, uv + Circle(Start, 14.0, 13.0) * Scale).rgb;
				float3 N14 = tex2D(TexChannel0, uv).rgb;
				
				float W = 1.0 / 15.0;
				
				float3 color = float3(0,0,0);
				
				color.rgb =
				(N0 * W) +
				(N1 * W) +
				(N2 * W) +
				(N3 * W) +
				(N4 * W) +
				(N5 * W) +
				(N6 * W) +
				(N7 * W) +
				(N8 * W) +
				(N9 * W) +
				(N10 * W) +
				(N11 * W) +
				(N12 * W) +
				(N13 * W) +
				(N14 * W);
				
				fragColor = float4(color.rgb,1.0);
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

