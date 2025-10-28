
// Anisotropic Kuwahara Filtering on the GPU
// www.kyprianidis.com
// Paper : http://www.kyprianidis.com/p/pg2009/jkyprian-pg2009.pdf
// Preview App' : https://code.google.com/archive/p/gpuakf/downloads
// Code : https://code.google.com/archive/p/gpuakf/source/default/source
// Use this code in accordance to the license holder's license !

// this shader is an extracted pass used inside KuwaharaAKF1

Shader "ImageFilter/Passes/KuwaGauss"
{
	Properties
	{
		
	}
	
	
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
		
		
		
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
		
		
		v2f CustomVert (Attributes v)
		{
			v2f o;
			o.vertex =  GetFullScreenTriangleVertexPosition(v.vertexID);
			o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
			o.screenPos = o.vertex;
			
			return o;
		}

		
		// by Jan Eric Kyprianidis <www.kyprianidis.com>
		//#extension GL_EXT_gpu_shader4 : enable
		//uniform sampler2D src;
		
		void mainImage( out float4 fragColor, in float2 fragCoord ) {
			const float sigma = 2;
			float2 src_size = _BlitTexture_TexelSize.zw;
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
						float3 c = SAMPLE_TEXTURE2D(_BlitTexture,  sampler_LinearClamp, uv + float2(i,j) / src_size ).rgb;
						sum += kernel * c;
						norm += kernel;
					}
				}
				} else {
				sum = SAMPLE_TEXTURE2D(_BlitTexture,  sampler_LinearClamp, uv).rgb * 0;
				norm = 1.0;
			}
			fragColor = float4(sum / norm, 1);
		}
		
		
		float4 CustomPostProcess (v2f i) : SV_Target
		{
			float4 col = 0;
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
		ENDHLSL

	SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "DitherPixelatePass"
            HLSLPROGRAM
            #pragma vertex CustomVert
            #pragma fragment CustomPostProcess
            ENDHLSL
        }
	}
}

