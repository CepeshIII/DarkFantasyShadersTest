// Shader source :
// https://pastebin.com/xprqDtjk

Shader "Hidden/Custom/Kuwahara/Tonynogo/OilPaintingURP"
{
    Properties
    {
        _BlitTexture("Source", 2D) = "white" {}
        _EffectsRadius("Radius", Range(0, 10)) = 3
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    float _EffectsRadius;

    // Fragment logic
    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord;
        float3 mean[4] = {
            {0, 0, 0},
            {0, 0, 0},
            {0, 0, 0},
            {0, 0, 0}
        };
 
        float3 sigma[4] = {
            {0, 0, 0},
            {0, 0, 0},
            {0, 0, 0},
            {0, 0, 0}
        };
        
        float2 start[4] = {{-_EffectsRadius, -_EffectsRadius}, {-_EffectsRadius, 0}, {0, -_EffectsRadius}, {0, 0}};

        float2 pos;
        float3 col;

        // Compute color averages in 4 quadrants
        [loop]
        for (int k = 0; k < 4; k++)
        {
            [loop]
            for (int i = 0; i <= _EffectsRadius; i++)
            {
                [loop]
                for (int j = 0; j <= _EffectsRadius; j++)
                {
                    pos = float2(i, j) + start[k];
                    float2 offset = uv + pos * _BlitTexture_TexelSize.xy;
                    col = SAMPLE_TEXTURE2D_LOD(_BlitTexture, sampler_LinearClamp, offset, 0).rgb;
                    mean[k] += col;
                    sigma[k] += col * col;
                }
            }
        }

        float n = pow(_EffectsRadius + 1, 2);
        float3 finalColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        float minSigma = 1e9;

        // Find region with smallest variance
        [unroll]
        for (int l = 0; l < 4; l++)
        {
            mean[l] /= n;
            sigma[l] = abs(sigma[l] / n - mean[l] * mean[l]);
            float sigmaSum = sigma[l].r + sigma[l].g + sigma[l].b;

            if (sigmaSum < minSigma)
            {
                minSigma = sigmaSum;
                finalColor = mean[l];
            }
        }

        return float4(finalColor, 1);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }

        ZWrite Off
        ZTest Always
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "OilPaintingPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }

    Fallback Off
}
