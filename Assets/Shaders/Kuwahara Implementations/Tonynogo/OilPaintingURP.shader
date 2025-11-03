// Shader source :
// https://pastebin.com/xprqDtjk

Shader "Hidden/Custom/Kuwahara/Tonynogo/OilPaintingURP"
{
    Properties
    {
        _Radius("Radius", Range(0, 10)) = 3
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    int _Radius;
    float _LerpValue;

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
        
        float2 start[4] = {{-_Radius, -_Radius}, {-_Radius, 0}, {0, -_Radius}, {0, 0}};

        float2 pos;
        float3 col;

        // Compute color averages in 4 quadrants
        [unroll]
        for (int k = 0; k < 4; k++)
        {
            [loop]
            for (int i = 0; i <= _Radius; i++)
            {
                [loop]
                for (int j = 0; j <= _Radius; j++)
                {
                    pos = float2(i, j) + start[k];
                    float2 offset = uv + pos * _BlitTexture_TexelSize.xy;
                    col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, offset).rgb;
                    mean[k] += col;
                    sigma[k] += col * col;
                }
            }
        }

        float n = pow(_Radius + 1, 2);
        float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
        float3 finalColor = baseColor;
        float minSigma = 1e9;

        // Find region with smallest variance
        [unroll]
        for (int l = 0; l < 4; l++)
        {
            mean[l] /= n;
            sigma[l] = abs(sigma[l] / n - mean[l] * mean[l]);
            float sigmaSum = sigma[l].r + sigma[l].g + sigma[l].b;

            bool condition = sigmaSum < minSigma;
            minSigma = condition ? sigmaSum : minSigma;
            finalColor = condition ? mean[l] : finalColor;
            //if (condition)
            //{
            //    minSigma = sigmaSum;
            //    finalColor = mean[l];
            //}
        }

        return float4(lerp(baseColor, finalColor, _LerpValue), 1);
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
        Blend Off

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
