
// Anisotropic Kuwahara Filtering on the GPU
// www.kyprianidis.com
// Paper : http://www.kyprianidis.com/p/pg2009/jkyprian-pg2009.pdf
// Preview App' : https://code.google.com/archive/p/gpuakf/downloads
// Code : https://code.google.com/archive/p/gpuakf/source/default/source
// Use this code in accordance to the license holder's license !

// this shader is an extracted pass used inside KuwaharaAKF1

Shader "ImageFilter/Passes/KuwaSST"
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

			#define src _GrabTexture
			#define textureSize2D(x,y) _GrabTexture_TexelSize.zw
			
			// by Jan Eric Kyprianidis <www.kyprianidis.com>
			//uniform sampler2D src;
			
			void mainImage( out float4 fragColor, in float2 fragCoord ) {
				float2 src_size = (textureSize2D(src, 0));
				float2 uv = fragCoord.xy / src_size;
				float2 d = 1.0 / src_size;
				
				float3 c = tex2D(src, uv).xyz;
				float3 u = (
				-1.0 * tex2D(src, uv + float2(-d.x, -d.y)).xyz +
				-2.0 * tex2D(src, uv + float2(-d.x,  0.0)).xyz +
				-1.0 * tex2D(src, uv + float2(-d.x,  d.y)).xyz +
				+1.0 * tex2D(src, uv + float2( d.x, -d.y)).xyz +
				+2.0 * tex2D(src, uv + float2( d.x,  0.0)).xyz +
				+1.0 * tex2D(src, uv + float2( d.x,  d.y)).xyz
				) / 4.0;
				
				float3 v = (
				-1.0 * tex2D(src, uv + float2(-d.x, -d.y)).xyz +
				-2.0 * tex2D(src, uv + float2( 0.0, -d.y)).xyz +
				-1.0 * tex2D(src, uv + float2( d.x, -d.y)).xyz +
				+1.0 * tex2D(src, uv + float2(-d.x,  d.y)).xyz +
				+2.0 * tex2D(src, uv + float2( 0.0,  d.y)).xyz +
				+1.0 * tex2D(src, uv + float2( d.x,  d.y)).xyz
				) / 4.0;
				
				fragColor = float4(dot(u, u), dot(v, v), dot(u, v), 1.0);
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

