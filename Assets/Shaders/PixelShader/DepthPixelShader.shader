Shader "Hidden/Shader/BetterPixelVolume"
{
    Properties
    {
        _Radius ("Sample Radius", Range(0, 10)) = 2
        _Intensity ("Blend Intensity", Range(0, 1)) = 1

        _Layer1Size ("Layer 1 Pixel Size", Float) = 100
        _Layer2Size ("Layer 2 Pixel Size", Float) = 150
        _Layer3Size ("Layer 3 Pixel Size", Float) = 250
        _Layer4Size ("Layer 4 Pixel Size", Float) = 500
        _Layer5Size ("Layer 5 Pixel Size", Float) = 1000

        _LayerThreshold1 ("Layer Threshold 1", Range(0, 1)) = 0.00
        _LayerThreshold2 ("Layer Threshold 2", Range(0, 1)) = 0.25
        _LayerThreshold3 ("Layer Threshold 3", Range(0, 1)) = 0.50
        _LayerThreshold4 ("Layer Threshold 4", Range(0, 1)) = 0.75
        _LayerThreshold5 ("Layer Threshold 5", Range(0, 1)) = 1.00
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Assets/Shaders/MyShaderFunctions.hlsl"

    // --- Texture Inputs ---
    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    // --- Uniforms ---
    float _Intensity;
    float _Radius;
    float _GridSize;
    float _NearPixelSize;
    float _FarPixelSize;

    float _Layer1Size;
    float _Layer2Size;
    float _Layer3Size;
    float _Layer4Size;
    float _Layer5Size;

    float _LayerThreshold1;
    float _LayerThreshold2;
    float _LayerThreshold3;
    float _LayerThreshold4;
    float _LayerThreshold5;


    // Convert desired pixel size (in screen px) to UV step
    inline float2 PixelSizeUV(float px)
    {
        return float2(px / _ScreenParams.x, px / _ScreenParams.y);
    }


    // --- Main Fragment ---
    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord;
        half3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, uv).rgb;
        float2 pixelAspect = SquarePixelUvFactor(_BlitTexture_TexelSize.zw);

        // Find nearest depth in the sampling radius
        half nearestDepth = 1.0h;
        float2 nearestUV = uv;
        half2 texelSize = _BlitTexture_TexelSize.xy;
        int radius = (int)_Radius;

        [loop]
        for (int x = -radius; x <= radius; x++)
        {
            [loop]
            for (int y = -radius; y <= radius; y++)
            {
                float2 offset = uv + float2(x * texelSize.x, y * texelSize.y);
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, offset).r;
                float linearDepth = Linear01Depth(rawDepth, _ZBufferParams);

                bool isNearer = (linearDepth < nearestDepth);
                nearestDepth = isNearer ? linearDepth : nearestDepth;
                nearestUV = isNearer ? offset : nearestUV;
            }
        }

        // Layer-based pixel scaling
        float maskA = step(nearestDepth, _LayerThreshold1);
        float maskB = step(_LayerThreshold1, nearestDepth) * step(nearestDepth, _LayerThreshold2);
        float maskC = step(_LayerThreshold2, nearestDepth) * step(nearestDepth, _LayerThreshold3);
        float maskD = step(_LayerThreshold3, nearestDepth) * step(nearestDepth, _LayerThreshold4);
        float maskE = step(_LayerThreshold4, nearestDepth) * step(nearestDepth, _LayerThreshold5);

        float pixelSize =
            maskA * _Layer1Size +
            maskB * _Layer2Size +
            maskC * _Layer3Size +
            maskD * _Layer4Size +
            maskE * _Layer5Size;

        // Quantize UV for pixelation
        float2 quantizedUV = round(uv * pixelAspect * pixelSize) / pixelSize;
        half3 quantizedColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, quantizedUV / pixelAspect).rgb;

        // Blend original and pixelated color
        half3 finalColor = lerp(baseColor, quantizedColor, _Intensity);
        return half4(finalColor, 1.0h);
    }
    ENDHLSL

    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            Name "Better Pixel Volume"
            ZWrite Off
            ZTest Always
            Cull Off
            Blend Off

            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }

    Fallback Off
}
