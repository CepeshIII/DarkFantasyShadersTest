

// Modified version of "Bilateral Filter to Look Younger"
// by "starea" @ https://www.shadertoy.com/view/XtVGWG which is itself a derivative of other works
// Use this code in accordance to the license holder's license !

Shader "ImageFilter/Bilateral Filter"
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
			
			#define SIGMA 10.0
			#define BSIGMA 0.1
			#define MSIZE 15
			#define USE_CONSTANT_KERNEL
			//#define GAMMA_CORRECTION
			
			float kernel[MSIZE];
			
			float normpdf(in float x, in float sigma) {
				return 0.39894 * exp(-0.5 * x * x/ (sigma * sigma)) / sigma;
			}
			
			float normpdf3(in float3 v, in float sigma) {
				return 0.39894 * exp(-0.5 * dot(v,v) / (sigma * sigma)) / sigma;
			}
			
			float normalizeColorChannel(in float value, in float min, in float max) {
				return (value - min)/(max-min);
			}
			
			void mainImage( out float4 fragColor, in float2 fragCoord ) {
				float3 c = tex2D(TexChannel0, (fragCoord.xy / _ScreenParams.xy)).rgb;
				const int kSize = (MSIZE - 1) / 2;
				float3 final_colour = (0.0);
				float Z = 0.0;
				
				#ifdef USE_CONSTANT_KERNEL
				// unfortunately, WebGL 1.0 does not support constant arrays...
				kernel[0] = kernel[14] = 0.031225216;
				kernel[1] = kernel[13] = 0.033322271;
				kernel[2] = kernel[12] = 0.035206333;
				kernel[3] = kernel[11] = 0.036826804;
				kernel[4] = kernel[10] = 0.038138565;
				kernel[5] = kernel[9]  = 0.039104044;
				kernel[6] = kernel[8]  = 0.039695028;
				kernel[7] = 0.039894000;
				float bZ = 0.2506642602897679;
				#else
				//create the 1-D kernel
				for (int j = 0; j <= kSize; ++j) {
					kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), SIGMA);
				}
				float bZ = 1.0 / normpdf(0.0, BSIGMA);
				#endif
				
				
				float3 cc;
				float factor;
				//read out the texels
				for (int i=-kSize; i <= kSize; ++i)
				{
					for (int j=-kSize; j <= kSize; ++j)
					{
						cc = tex2D(TexChannel0, (fragCoord.xy+float2(float(i),float(j))) / _ScreenParams.xy).rgb;
						factor = normpdf3(cc-c, BSIGMA) * bZ * kernel[kSize+j] * kernel[kSize+i];
						Z += factor;
                        #ifdef GAMMA_CORRECTION
                        final_colour += factor * pow(cc, 2.2);
                        #else
                        final_colour += factor * cc;
                        #endif
						
					}
				}
				
                #ifdef GAMMA_CORRECTION
					fragColor = float4(pow(final_colour / Z, (1.0/2.2)), 1.0);
				#else
					fragColor = float4(final_colour / Z, 1.0);
				#endif
				
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

