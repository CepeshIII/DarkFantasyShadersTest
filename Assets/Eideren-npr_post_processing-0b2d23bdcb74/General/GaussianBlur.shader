
// Gaussian Blur by mrharicot @ https://www.shadertoy.com/view/XdfGDH
// Use this code in accordance to the license holder's license !

Shader "ImageFilter/GaussianBlur"
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
			
			#ifdef GL_ES
			precision mediump float;
			#endif
			
			float normpdf(in float x, in float sigma)
			{
				return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
			}
			
			
			void mainImage( out float4 fragColor, in float2 fragCoord )
			{
				float3 c = tex2D(TexChannel0, fragCoord.xy / _ScreenParams.xy).rgb;
					
                //declare stuff
                const int mSize = 11;
                const int kSize = (mSize-1)/2;
                float kernel[mSize];
                float3 final_colour = (0.0);
                
                //create the 1-D kernel
                float sigma = 7.0;
                float Z = 0.0;
                for (int j = 0; j <= kSize; ++j)
                {
                    kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), sigma);
                }
                
                //get the normalization factor (as the gaussian has been clamped)
                for (int j = 0; j < mSize; ++j)
                {
                    Z += kernel[j];
                }
                
                //read out the texels
                for (int i=-kSize; i <= kSize; ++i)
                {
                    for (int j=-kSize; j <= kSize; ++j)
                    {
                        final_colour += kernel[kSize+j]*kernel[kSize+i]*tex2D(TexChannel0, (fragCoord.xy+float2(float(i),float(j))) / _ScreenParams.xy).rgb;
                    }
                }
                
                fragColor = float4(final_colour/(Z*Z), 1.0);
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

