Shader "Hidden/Custom/Pallete"
{
    Properties
    {
        _PalleteTex("Pallete Texture", 2D) = "gray" {}
        _Levels("Levels", Range(1, 16)) = 8
        _Threshold("Threshold", Range(0, 1)) = 0.5
        _Colors("Colors", Range(1, 32)) = 8
        _Pixelate("Pixelate", Range(1, 10)) = 4

        _LerpValue("LerpValue", Range(0, 1)) = 1
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    #include "Assets/Shaders/ColorPalette.hlsl"


    TEXTURE2D(_PalleteTex);
    SAMPLER(sampler_PalleteTex);

    float4 _PalleteTex_TexelSize;

    float _Levels;
    float _Threshold;
    float _Colors;
    float _Pixelate;

    float _LerpValue;


    void Unity_Dither_float4(float4 In, float4 ScreenPosition, out float4 Out)
    {
        float2 uv = ScreenPosition.xy / _Pixelate * _ScreenParams.xy;
        float DITHER_THRESHOLDS[16] =
        {
            1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
            13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
            4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
            16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
        };
        uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
        Out = In - DITHER_THRESHOLDS[index];
    }


    float ditherChannel(float raw, float dither, float depth)
    {
        float div = 1.0 / depth;
        float val = 0.0;

        [unroll]
        for (int i = 0; i < 32; i++)
        {
            if (i >= depth) break;

            float border = div * (i + 1);
            if (raw <= border)
            {
                float diff = raw * depth - i;
                val = (diff <= dither * 0.999) ? div * i : div * (i + 1);
                break;
            }
        }

        if (raw >= 1.0)
            val = 1.0;

        return val;
    }

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);

        float3 nearestColor = GetNearestColor(color, _PalleteTex, sampler_PalleteTex, _PalleteTex_TexelSize.z);
        return float4(nearestColor, 1);
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
