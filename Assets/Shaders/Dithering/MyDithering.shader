Shader "Hidden/Custom/DitherPixelate"
{
    Properties
    {
        _Pixelate("Pixelate", Range(0, 0.025)) = 0.1
        _LerpValue("LerpValue", Range(0, 1)) = 1
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Assets/Shaders/MyShaderFunctions.hlsl"

    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    float _Pixelate;
    float _LerpValue;


    static const float DITHER_THRESHOLDS[16] = 
    {
        0, 8, 2, 10,
        12, 4, 14, 6, 
        3, 11, 1, 9, 
        15, 7, 13, 5
    };


    void Unity_Dither_float4(float4 In, float4 ScreenPosition, out float4 Out)
    {
        float2 pixelAspect = SquarePixelUvFactor(_BlitTexture_TexelSize.zw);

        float2 uv = (ScreenPosition.xy * pixelAspect) / _Pixelate;
        uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;

        Out = In + (DITHER_THRESHOLDS[index] * (1.0/17.0) - 0.5);
    }


    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float4 screenCol = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
        float4 uv = float4(input.texcoord, 1, 1);
        float4 result;
        Unity_Dither_float4(screenCol, uv, result);
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
