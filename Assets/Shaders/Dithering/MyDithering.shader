Shader "Hidden/Custom/DitherPixelate"
{
    Properties
    {
        _DitherTex("Dither Texture", 2D) = "gray" {}
        _Levels("Levels", Range(1, 16)) = 8
        _Threshold("Threshold", Range(0, 1)) = 0.5
        _Colors("Colors", Range(1, 32)) = 8

        _Pixelate("Pixelate", Range(1, 10)) = 4
        _LerpValue("LerpValue", Range(0, 1)) = 1
        _BlueNoiseScale("_BlueNoiseScale", Range(0, 30)) = 1
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        TEXTURE2D(_CameraDepthTexture);
    // DEPTH_TEXTURE(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    TEXTURE2D(_DitherTex);

    SAMPLER(sampler_DitherTex);
    float _BlueNoiseScale;
    float4 _DitherTex_TexelSize;

    float _Levels;
    float _Threshold;
    float _Colors;
    float _Pixelate;

    float _LerpValue;

    static const float DITHER_THRESHOLDS[16] = {
        1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };

    static const float DITHER_THRESHOLDS2[16] = {
        0, 8, 2, 10,
        12, 4, 14, 6, 
        3, 11, 1, 9, 
        15, 7, 13, 5
    };


    void Unity_Dither_float4(float4 In, float4 ScreenPosition, out float4 Out)
    {
        //float2 uv = ScreenPosition.xy / _Pixelate * _ScreenParams.xy;
        float2 uv = (ScreenPosition.xy * _ScreenParams.xy) / _Pixelate;
        uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;

        Out = In + DITHER_THRESHOLDS2[index] * (1.0/17.0) - 0.5;
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

    float3 TriangularNoise(float3 n) {
        n = mad(n, 2.0, - 1.0);

        return sign(n) * (1.0 - sqrt(1.0 - abs(n)));
    }


    float4 Dithering(float3 color, float depth, float2 uv)
    {
        // Sample blue noise (tiled)
        float2 noiseUV = frac(uv * _BlueNoiseScale);
        float3 blueNoise = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, noiseUV).rgb;
        blueNoise = TriangularNoise(blueNoise);

        // blueNoise=mad(blueNoise,2.0f,-1.0f); 
        // blueNoise=sign(blueNoise)*(1.0f-sqrt(1.0f-abs(blueNoise)));

        // Apply dithering in sRGB space
        float3 sRGB = LinearToSRGB(color);
        sRGB += blueNoise / 256 * abs(depth);
        sRGB = saturate(sRGB);

        // Convert back to linear
        color = SRGBToLinear(sRGB);
        return float4(color, 1);
    }


    float4 ComputeDitheredScatteringColor(float4 color, float4 uv)
    {
        float noise = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, uv.xy / _DitherTex_TexelSize.zw).r;
        color.rgb += (noise - 0.5) / 16;
        return color;
    }

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        //// Pixelate UVs
        //float2 uv = input.texcoord;
        //float2 screenSize = _ScreenParams.xy / _Pixelate;
        //float2 sampleUV = floor(uv * screenSize) / screenSize;
        //
        //// Dither tiling
        //float2 ditherSize = _DitherTex_TexelSize.zw;
        //float2 ditherUV = fmod(uv * screenSize, ditherSize) / ditherSize;
        //
        //// Sample screen and dither
        //float3 screenCol = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, sampleUV).rgb;
        //float ditherLum = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, ditherUV).r;
        //
        //float ditherAmt = _Threshold * ditherLum;
        //float3 quantCol;
        //
        //// Quantize each RGB channel
        //[unroll]
        //for (int i = 0; i < 3; i++)
        //{
        //   float raw = screenCol[i];
        //   float q = ditherChannel(raw, ditherAmt, _Levels);
        //   quantCol[i] = floor(q * _Colors) / (_Colors - 1);
        //}
        //return float4(quantCol, 1.0);

        float4 screenCol = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
            //half depth = Linear01Depth(
            //    SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.texcoord).r,
            //    _ZBufferParams
            //);
        float4 uv = float4(input.texcoord, 1, 1);

        float4 result;
        Unity_Dither_float4(screenCol, uv, result);


        //float2 screenRatio = float2(_ScreenParams.x / _ScreenParams.y, 1.0);
        //float2 noiseUV =  uv ;

        //float4 result = Dithering(screenCol.rgb, depth, noiseUV);


        // result = ComputeDitheredScatteringColor(screenCol, uv);

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
