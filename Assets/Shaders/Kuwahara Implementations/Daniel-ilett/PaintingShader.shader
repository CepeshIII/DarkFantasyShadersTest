// Shader source :
// https://github.com/daniel-ilett/smo-shaders/blob/master/Assets/Shaders/Complete/Painting.shader

Shader "Hidden/Custom/Kuwahara/daniel-ilett/PaintingShader"
{
    Properties
    {
        _KernelSize("Kernel Size (N)", Range(1, 20)) = 17
        _LerpValue("Lerp Value", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        ZWrite Off
        ZTest Always
        Cull Off
        Blend Off

        Pass
        {
            Name "Painting"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            // URP / Core includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Fullscreen vertex utilities (Vert() + attributes + varyings)
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            int _KernelSize;
            float _LerpValue;

            struct region
            {
                float3 mean;
                float variance;
            };

            region CalcRegion(int2 lower, int2 upper, int samples, float2 uv)
            {
                region r;
                float3 sum = 0.0;
                float3 squareSum = 0.0;

                [loop]
                for (int x = lower.x; x <= upper.x; ++x)
                {
                    [loop]
                    for (int y = lower.y; y <= upper.y; ++y)
                    {
                        float2 offset = float2(x, y) * _BlitTexture_TexelSize.xy;
                        float3 tex = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + offset).rgb;
                        sum += tex;
                        squareSum += tex * tex;
                    }
                }

                r.mean = sum / samples;
                float3 variance = abs((squareSum / samples) - (r.mean * r.mean));
                r.variance = length(variance);
                return r;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                int upper = (_KernelSize - 1) / 2u;
                int lower = -upper;
                int samples = (upper + 1) * (upper + 1);

                region regionA = CalcRegion(int2(lower, lower), int2(0, 0), samples, uv);
                region regionB = CalcRegion(int2(0, lower), int2(upper, 0), samples, uv);
                region regionC = CalcRegion(int2(lower, 0), int2(0, upper), samples, uv);
                region regionD = CalcRegion(int2(0, 0), int2(upper, upper), samples, uv);

                float3 col = regionA.mean;
                float minVar = regionA.variance;

                float testVal;

                testVal = step(regionB.variance, minVar);
                col = lerp(col, regionB.mean, testVal);
                minVar = lerp(minVar, regionB.variance, testVal);

                testVal = step(regionC.variance, minVar);
                col = lerp(col, regionC.mean, testVal);
                minVar = lerp(minVar, regionC.variance, testVal);

                testVal = step(regionD.variance, minVar);
                col = lerp(col, regionD.mean, testVal);

                return float4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
