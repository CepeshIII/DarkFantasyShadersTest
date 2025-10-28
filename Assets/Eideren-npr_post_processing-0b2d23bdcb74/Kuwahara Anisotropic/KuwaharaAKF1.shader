


// Anisotropic Kuwahara Filtering on the GPU
// www.kyprianidis.com
// Paper : http://www.kyprianidis.com/p/pg2009/jkyprian-pg2009.pdf
// Preview App' : https://code.google.com/archive/p/gpuakf/downloads
// Code : https://code.google.com/archive/p/gpuakf/source/default/source
// Use this code in accordance to the license holder's license !

// This Shader is a brute-force implementation of the Shader Pass chain implemented inside 
// the source application and as such should not be implemented as-is inside a game, use command buffers / compute shaders.
// It's also not a perfect port, we can't properly store the values computed inside SST without saturating them so I had to encode them,
// you should remove the encoding/decoding once you're working with proper texture formats

Shader "ImageFilter/KuwaharaAKF1(Heavy)"
{
	Properties
	{
	    // This texture is used as a modulator for the screen sampling, 
	    // search for kernel1 or kernel1111  
		K0 ("K0:kernel1", 2D) = "white" {}
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Overlay"
			"Queue"="Overlay"
		}
		ZWrite Off
		
		// store rendered scene
		GrabPass{ "ScreenRaw" }


        
		// DO SST : edge detection
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
			
			#define _GrabTexture ScreenRaw
			#define _GrabTexture_TexelSize ScreenRaw_TexelSize

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
				// keep dots inside texture format range
				fragColor.xyz = fragColor.xyz*0.5+0.5;
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
		GrabPass{ "SST" }



		// BLUR SST
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
			
			#define _GrabTexture SST
			#define _GrabTexture_TexelSize SST_TexelSize

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
			//#extension GL_EXT_gpu_shader4 : enable
			//uniform sampler2D src;
			
			void mainImage( out float4 fragColor, in float2 fragCoord ) {
				const float sigma = 2;
				float2 src_size = (textureSize2D(src, 0));
				float2 uv = fragCoord.xy / src_size;
				float twoSigma2 = 2.0 * sigma * sigma;
				int halfWidth = int(ceil( 2.0 * sigma ));
				
				float3 sum = (0.0);
				float norm = 0.0;
				if (halfWidth > 0) {
					for ( int i = -halfWidth; i <= halfWidth; ++i ) {
						for ( int j = -halfWidth; j <= halfWidth; ++j ) {
							float d = length(float2(i,j));
							float kernel = exp( -d *d / twoSigma2 );
							float3 c = tex2D(src, uv + float2(i,j) / src_size ).rgb;
							sum += kernel * c;
							norm += kernel;
						}
					}
					} else {
					sum = tex2D(src, uv).rgb;
					norm = 1.0;
				}
				fragColor = float4(sum / norm, 1);
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
		GrabPass{ "SST_BLURRED" }



		// DO TFM
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
			#define _GrabTexture SST_BLURRED
			#define _GrabTexture_TexelSize SST_BLURRED_TexelSize

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
				// remap from encoded texture range
				g = g*2-1;
				
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
				
				// note that A isn't used inside any pass of this shader, this pass was used by other shaders as well on the source app
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
		GrabPass{ "ScreenTFM" }


        // COMPUTE KUWAHARA_AKF1
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

			#define _GrabTexture ScreenRaw
			#define _GrabTexture_TexelSize ScreenRaw_TexelSize
			
			#define tfm ScreenTFM

			sampler2D _GrabTexture;
			float4 _GrabTexture_TexelSize;
			
			sampler2D tfm;
			sampler2D SST_BLURRED;
			
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
			uniform sampler2D K0;
			
			
			void mainImage( out float4 fragColor, in float2 fragCoord ) {
				
				const float alpha = 1;
				const int N = 8;
				const float radius = 6;
				const float q = 8;
				
				
				const float PI = 3.14159265358979323846;
				float2 src_size = (textureSize2D(src, 0));
				float2 uv = fragCoord.xy / src_size;
				
				float4 m[8];
				float3 s[8];
				for (int k = 0; k < N; ++k) {
					m[k] = (0.0);
					s[k] = (0.0);
				}
				
				float piN = 2.0 * PI / float(N);
				float2x2 X = float2x2(cos(piN), sin(piN), -sin(piN), cos(piN));
				
				float4 sampledTFM = tex2D(tfm, uv);
				float a = radius * clamp((alpha + sampledTFM.w) / alpha, 0.1, 2.0);
				float b = radius * clamp(alpha / (alpha + sampledTFM.w), 0.1, 2.0);
				
				float cos_phi = cos(sampledTFM.z);
				float sin_phi = sin(sampledTFM.z);
				
				float2x2 R = float2x2(cos_phi, -sin_phi, sin_phi, cos_phi);
				float2x2 S = float2x2(0.5/a, 0.0, 0.0, 0.5/b);
				float2x2 SR = S * R;
				
				int max_x = int(sqrt(a*a * cos_phi*cos_phi +
				b*b * sin_phi*sin_phi));
				int max_y = int(sqrt(a*a * sin_phi*sin_phi +
				b*b * cos_phi*cos_phi));
				
				for (int j = -max_y; j <= max_y; ++j) {
					for (int i = -max_x; i <= max_x; ++i) {
						float2 v = mul(SR, float2(i,j));
						if (dot(v,v) <= 0.25) {
							float4 c_fix = tex2Dlod(src, float4(uv + float2(i,j) / src_size, 0, 0));
							float3 c = c_fix.rgb;
							for (int k = 0; k < N; ++k) {
								float w = tex2Dlod(K0, float4(float2(0.5, 0.5) + v, 0, 0)).x;
								
								m[k] += float4(c * w, w);
								s[k] += c * c * w;
								
								v = mul(X, v);//v *= X;
							}
						}
					}
				}
				
				float4 o = (0.0);
				for (int k = 0; k < N; ++k) {
					m[k].rgb /= m[k].w;
					s[k] = abs(s[k] / m[k].w - m[k].rgb * m[k].rgb);
					
					float sigma2 = s[k].r + s[k].g + s[k].b;
					float w = 1.0 / (1.0 + pow(255.0 * sigma2, 0.5 * q));
					
					o += float4(m[k].rgb * w, w);
				}
				fragColor = float4(o.rgb / o.w, 1.0);
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