// Shader source :
// https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Edge%20Detection/DifferenceOfGaussians.shader


Shader "Hidden/DifferenceOfGaussians" 
{
    
    Properties 
    {
        _BlitTexture ("Texture", 2D) = "white" {}
        
        _GaussianKernelSize ("GaussianKernelSize", Int) = 1
        _Thresholding ("Thresholding", Int) = 1
        _Invert ("Invert", Int) = 1
        _Tanh ("_Tanh", Int) = 1

        _Sigma ("Sigma", Float) = 2.0
        _Threshold ("Threshold", Float) = 0.1
        _K ("K", Float) = 1.6
        _Tau ("Tau", Float) = 0.99
        _Phi ("Phi", Float) = 10.0
    }

    HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

        int _GaussianKernelSize, _Thresholding, _Invert, _Tanh;
        float _Sigma, _Threshold, _K, _Tau, _Phi;

        
        float gaussian(float sigma, float pos) {
            return (1.0f / sqrt(2.0f * PI * sigma * sigma)) * exp(-(pos * pos) / (2.0f * sigma * sigma));
        }

        float luminance(float3 color) {
            return dot(color, float3(0.299f, 0.587f, 0.114f));
        }

    ENDHLSL

    SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off

        Pass
        {
            Name "Blur Pass 1"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM 

            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target {
                float2 col = 0;
                float kernelSum1 = 0.0f;
                float kernelSum2 = 0.0f;

                for (int x = -_GaussianKernelSize; x <= _GaussianKernelSize; ++x) {
                    float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(x, 0) * _BlitTexture_TexelSize.xy);
                    float c = luminance(color.rgb);
                    float gauss1 = gaussian(_Sigma, x);
                    float gauss2 = gaussian(_Sigma * _K, x);

                    col.r += c * gauss1;
                    kernelSum1 += gauss1;

                    col.g += c * gauss2;
                    kernelSum2 += gauss2;
                }

                return float4(col.r / kernelSum1, col.g / kernelSum2, 0, 0);
            }

            ENDHLSL
        }


        Pass
        {
            Name "Blur Pass 2"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM 

            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target {
                float2 col = 0;
                float kernelSum1 = 0.0f;
                float kernelSum2 = 0.0f;

                for (int y = -_GaussianKernelSize; y <= _GaussianKernelSize; ++y) {
                    float4 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(0, y) * _BlitTexture_TexelSize.xy);
                    float gauss1 = gaussian(_Sigma, y);
                    float gauss2 = gaussian(_Sigma * _K, y);

                    col.r += c.r * gauss1;
                    kernelSum1 += gauss1;

                    col.g += c.g * gauss2;
                    kernelSum2 += gauss2;
                }

                return float4(col.r / kernelSum1, col.g / kernelSum2, 0, 0);
            }

            ENDHLSL
        }


        Pass
        {
            Name "Difference Of Gaussians"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM 
    
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target {
                float2 G = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rg;

                float4 D = (G.r - _Tau * G.g);

                if (_Thresholding) {
                    if (_Tanh)
                        D = (D >= _Threshold) ? 1 : 1 + tanh(_Phi * (D - _Threshold));
                    else
                        D = (D >= _Threshold) ? 1 : 0;
                }

                if (_Invert)
                    D = 1 - D;

                return D;
            }

            ENDHLSL
        }
    }

    Fallback Off
}