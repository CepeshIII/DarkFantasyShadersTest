Shader "Hidden/Custom/MyDithering"
{
    Properties
    {
        _Pixelate("Pixelate", Range(0, 25)) = 0.1
        _LerpValue("LerpValue", Range(0, 1)) = 1

        [KeywordEnum(Level2, Level4, Level8)] _Bayer ("Color Mode", int) = 0
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Assets/Shaders/MyShaderFunctions.hlsl"

    #pragma shader_feature _BAYER_LEVEL2 _BAYER_LEVEL4 _BAYER_LEVEL8

    
    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    float _Pixelate;
    float _LerpValue;

    
    static const int bayer2[2 * 2] = {
        0, 2,
        3, 1
    };

    static const int bayer4[4 * 4] = {
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    };

    static const int bayer8[8 * 8] = {
        0, 32, 8, 40, 2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,  
        12, 44,  4, 36, 14, 46,  6, 38, 
        60, 28, 52, 20, 62, 30, 54, 22,  
        3, 35, 11, 43,  1, 33,  9, 41,  
        51, 19, 59, 27, 49, 17, 57, 25, 
        15, 47,  7, 39, 13, 45,  5, 37, 
        63, 31, 55, 23, 61, 29, 53, 21
    };


    
    float GetBayer2(int x, int y) {
        return float(bayer2[(x % 2) + (y % 2) * 2]) * (1.0f / 4.0f) - 0.5f;
    }


    float GetBayer4(int x, int y) {
        return float(bayer4[(x % 4) + (y % 4) * 4]) * (1.0f / 16.0f) - 0.5f;
    }


    float GetBayer8(int x, int y) {
        return float(bayer8[(x % 8) + (y % 8) * 8]) * (1.0f / 64.0f) - 0.5f;
    }


    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float4 screenCol = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);

        int x = input.texcoord.x * _BlitTexture_TexelSize.z;
        int y = input.texcoord.y * _BlitTexture_TexelSize.w;

        float bayerValue = 0.0f;

        #ifdef _BAYER_LEVEL2
            bayerValue = GetBayer2((x) / _Pixelate, y / _Pixelate);
        #elif _BAYER_LEVEL4
            bayerValue = GetBayer4((x) / _Pixelate, y / _Pixelate);
        #elif _BAYER_LEVEL8
            bayerValue = GetBayer8((x) / _Pixelate, y / _Pixelate);
        #endif

        float4 result = screenCol + bayerValue;

        return lerp(screenCol, result, _LerpValue);
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
            #pragma vertex Vert
            #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }

    Fallback Off
}
