Shader "Hidden/URP/Kuwahara"
{
    Properties
    {
        _Radius ("Radius (int)", Int) = 4
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
        }

        ZWrite Off
        ZTest Always
        Cull Off
        Blend Off

        Pass
        {
            Name "Kuwahara"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0

            // URP includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Provides Vert(), Attributes, Varyings for full-screen blits
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            
            // Parameters
            int _Radius; // set from script/volume

            float3 SampleSrc(float2 uv)
            {
                return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv).rgb;
            }

            float4 KuwaharaFilter(float2 uv)
            {
                // Inverse texture size for integer pixel steps
                const float2 invSize = _BlitTexture_TexelSize.xy;

                // n = (r+1)^2 (area of each quadrant window)
                const float n = (float)(_Radius + 1) * (float)(_Radius + 1);

                float3 m[4];
                float3 s[4];
                [unroll] for (int k = 0; k < 4; ++k)
                {
                    m[k] = 0.0.xxx;
                    s[k] = 0.0.xxx;
                }

                // Q0: i,j in [-r..0]
                [loop] for (int j = -_Radius; j <= 0; ++j)
                {
                    [loop] for (int i = -_Radius; i <= 0; ++i)
                    {
                        float3 c = SampleSrc(uv + float2(i, j) * invSize);
                        m[0] += c;
                        s[0] += c * c;
                    }
                }

                // Q1: i in [0..r], j in [-r..0]
                [loop] for (int j = -_Radius; j <= 0; ++j)
                {
                    [loop] for (int i = 0; i <= _Radius; ++i)
                    {
                        float3 c = SampleSrc(uv + float2(i, j) * invSize);
                        m[1] += c;
                        s[1] += c * c;
                    }
                }

                // Q2: i,j in [0..r]
                [loop] for (int j = 0; j <= _Radius; ++j)
                {
                    [loop] for (int i = 0; i <= _Radius; ++i)
                    {
                        float3 c = SampleSrc(uv + float2(i, j) * invSize);
                        m[2] += c;
                        s[2] += c * c;
                    }
                }

                // Q3: i in [-r..0], j in [0..r]
                [loop] for (int j = 0; j <= _Radius; ++j)
                {
                    [loop] for (int i = -_Radius; i <= 0; ++i)
                    {
                        float3 c = SampleSrc(uv + float2(i, j) * invSize);
                        m[3] += c;
                        s[3] += c * c;
                    }
                }

                float minSigma2 = 1e+2;
                float3 outCol = 0;

                [unroll] for (int k = 0; k < 4; ++k)
                {
                    float3 mk = m[k] / n;
                    float3 sk = abs(s[k] / n - mk * mk); // per-channel variance
                    float sigma2 = sk.r + sk.g + sk.b;
                    if (sigma2 < minSigma2)
                    {
                        minSigma2 = sigma2;
                        outCol = mk;
                    }
                }

                return float4(outCol, 1);
            }

            half4 Frag (Varyings input) : SV_Target
            {
                // input.texcoord is already the correct screen UV for blit passes
                float2 uv = input.texcoord;
                return KuwaharaFilter(uv);
            }
            ENDHLSL
        }
    }

    Fallback Off
}
