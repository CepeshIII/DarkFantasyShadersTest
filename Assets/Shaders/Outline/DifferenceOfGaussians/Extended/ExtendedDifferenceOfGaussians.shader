// Shader source :
// https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Edge%20Detection/ExtendedDoG.cs


Shader "Hidden/ExtendedDoG_URP"
{
    Properties
    {
        [MainTexture] _BlitTexture ("Source Texture", 2D) = "white" {}
        _DogTex       ("DoG Texture", 2D) = "white" {}
        _HatchTex     ("Hatch Texture", 2D) = "gray" {}
        _TFM          ("TFM Texture", 2D) = "black" {}

        _Thresholding                ("Thresholding Mode", Int) = 1
        _Invert                      ("Invert", Int) = 0
        _CalcDiffBeforeConvolution   ("Calc Diff Before Convolution", Int) = 0
        _BlendMode                   ("Blend Mode", Int) = 0
        _HatchingEnabled             ("Hatching Enabled", Int) = 0
        _EnableSecondLayer           ("Enable Second Layer", Int) = 0
        _EnableThirdLayer            ("Enable Third Layer", Int) = 0
        _EnableFourthLayer           ("Enable Fourth Layer", Int) = 0
        _EnableColoredPencil         ("Enable Colored Pencil", Int) = 0

        _SigmaC      ("SigmaC", Float) = 1.0
        _SigmaE      ("SigmaE", Float) = 1.0
        _SigmaM      ("SigmaM", Float) = 1.0
        _SigmaA      ("SigmaA", Float) = 1.0

        _Threshold   ("Threshold",  Float) = 50.0
        _Threshold2  ("Threshold2", Float) = 60.0
        _Threshold3  ("Threshold3", Float) = 70.0
        _Threshold4  ("Threshold4", Float) = 80.0
        _Thresholds  ("Thresholds Count", Float) = 4.0

        _K           ("K",    Float) = 1.6
        _Tau         ("Tau",  Float) = 0.99
        _Phi         ("Phi",  Float) = 10.0

        _LineIntegralConvolutionStepSize ("LIC Step Size", Float) = 1.0
        _EdgeSmoothConvolutionStepSize   ("Edge Smooth Step Size", Float) = 1.0

        _BlendStrength  ("Blend Strength", Range(0,1)) = 1.0
        _DoGStrength    ("DoG Strength", Float) = 1.0

        _HatchTexRotation  ("Hatch Rotation 0", Float) = 0.0
        _HatchTexRotation1 ("Hatch Rotation 1", Float) = 45.0
        _HatchTexRotation2 ("Hatch Rotation 2", Float) = 90.0
        _HatchTexRotation3 ("Hatch Rotation 3", Float) = 135.0

        _HatchRes1 ("Hatch Res 1", Float) = 8.0
        _HatchRes2 ("Hatch Res 2", Float) = 8.0
        _HatchRes3 ("Hatch Res 3", Float) = 8.0
        _HatchRes4 ("Hatch Res 4", Float) = 8.0

        _BrightnessOffset ("Brightness Offset", Float) = 0.0
        _Saturation       ("Saturation", Range(0,1)) = 1.0

        _MinColor ("Min Color", Color) = (0,0,0,1)
        _MaxColor ("Max Color", Color) = (1,1,1,1)

        _IntegralConvolutionStepSizes ("Integral Step Sizes", Vector) = (1,1,1,1)
    }

    HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

        // Textures & samplers
        TEXTURE2D(_DogTex);
        SAMPLER(sampler_DogTex);

        TEXTURE2D(_HatchTex);
        SAMPLER(sampler_HatchTex);

        Texture2D    _TFM;
        SamplerState point_clamp_sampler;

        int   _Thresholding;
        int   _Invert;
        int   _CalcDiffBeforeConvolution;
        int   _BlendMode;
        int   _HatchingEnabled;
        int   _EnableSecondLayer;
        int   _EnableThirdLayer;
        int   _EnableFourthLayer;
        int   _EnableColoredPencil;

        float _SigmaC, _SigmaE, _SigmaM, _SigmaA;
        float _Threshold, _Threshold2, _Threshold3, _Threshold4, _Thresholds;
        float _K, _Tau, _Phi;
        float _LineIntegralConvolutionStepSize, _EdgeSmoothConvolutionStepSize;
        float _BlendStrength, _DoGStrength;
        float _HatchTexRotation, _HatchTexRotation1, _HatchTexRotation2, _HatchTexRotation3;
        float _HatchRes1, _HatchRes2, _HatchRes3, _HatchRes4;
        float _BrightnessOffset, _Saturation;

        float3 _MinColor;
        float3 _MaxColor;

        float4 _IntegralConvolutionStepSizes;


        float gaussian(float sigma, float pos) {
            return (1.0f / sqrt(2.0f * PI * sigma * sigma)) * exp(-(pos * pos) / (2.0f * sigma * sigma));
        }

        float luminance(float3 color) {
            return dot(color, float3(0.299f, 0.587f, 0.114f));
        }

         // Color conversions from https://gist.github.com/mattatz/44f081cac87e2f7c8980
        float3 rgb2xyz(float3 c) {
            float3 tmp;

            tmp.x = (c.r > 0.04045) ? pow((c.r + 0.055) / 1.055, 2.4) : c.r / 12.92;
            tmp.y = (c.g > 0.04045) ? pow((c.g + 0.055) / 1.055, 2.4) : c.g / 12.92,
            tmp.z = (c.b > 0.04045) ? pow((c.b + 0.055) / 1.055, 2.4) : c.b / 12.92;
            
            const float3x3 mat = float3x3(
                0.4124, 0.3576, 0.1805,
                0.2126, 0.7152, 0.0722,
                0.0193, 0.1192, 0.9505 
            );

            return 100.0 * mul(tmp, mat);
        }

        float3 xyz2lab(float3 c) {
            float3 n = c / float3(95.047, 100, 108.883);
            float3 v;

            v.x = (n.x > 0.008856) ? pow(n.x, 1.0 / 3.0) : (7.787 * n.x) + (16.0 / 116.0);
            v.y = (n.y > 0.008856) ? pow(n.y, 1.0 / 3.0) : (7.787 * n.y) + (16.0 / 116.0);
            v.z = (n.z > 0.008856) ? pow(n.z, 1.0 / 3.0) : (7.787 * n.z) + (16.0 / 116.0);

            return float3((116.0 * v.y) - 16.0, 500.0 * (v.x - v.y), 200.0 * (v.y - v.z));
        }

        float3 rgb2lab(float3 c) {
            float3 lab = xyz2lab(rgb2xyz(c));

            return float3(lab.x / 100.0f, 0.5 + 0.5 * (lab.y / 127.0), 0.5 + 0.5 * (lab.z / 127.0));
        }

    ENDHLSL

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        ZWrite Off
        Cull Off

        // --- Pass 0: RGB -> LAB ------------------------------------------------
        Pass
        {
            Name "RGBToLAB"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb;
                return float4(rgb2lab(col), 1.0f);
            }
            ENDHLSL
        }

        // --- Pass 1: Calculate Eigenvectors ------------------------------------
        Pass
        {
            Name "Eigenvectors"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float2 d = _BlitTexture_TexelSize.xy;

                float3 Sx = (
                    1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(-d.x, -d.y)).rgb +
                    2.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(-d.x,  0.0)).rgb +
                    1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(-d.x,  d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( d.x, -d.y)).rgb +
                    -2.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( d.x,  0.0)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( d.x,  d.y)).rgb
                ) / 4.0f;

                float3 Sy = (
                    1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(-d.x, -d.y)).rgb +
                    2.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( 0.0, -d.y)).rgb +
                    1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( d.x, -d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(-d.x,  d.y)).rgb +
                    -2.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( 0.0,  d.y)).rgb +
                    -1.0f * SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2( d.x,  d.y)).rgb
                ) / 4.0f;

                return float4(dot(Sx, Sx), dot(Sy, Sy), dot(Sx, Sy), 1.0f);
            }
            ENDHLSL
        }

        // --- Pass 2: TFM Blur Pass 1 (horizontal) ------------------------------
        Pass
        {
            Name "TFMBlur1"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                int kernelRadius = max(1, (int)floor(_SigmaC * 2.45f));

                float4 col = 0;
                float kernelSum = 0.0f;

                [loop]
                for (int x = -kernelRadius; x <= kernelRadius; ++x)
                {
                    float2 uv = i.texcoord + float2(x, 0) * _BlitTexture_TexelSize.xy;
                    float4 c  = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                    float gauss = gaussian(_SigmaC, (float)x);

                    col += c * gauss;
                    kernelSum += gauss;
                }

                return col / kernelSum;
            }
            ENDHLSL
        }

        // --- Pass 3: TFM Blur Pass 2 (vertical + eigen) ------------------------
        Pass
        {
            Name "TFMBlur2"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                int kernelRadius = max(1, (int)floor(_SigmaC * 2.45f));

                float4 col = 0;
                float kernelSum = 0.0f;

                [loop]
                for (int y = -kernelRadius; y <= kernelRadius; ++y)
                {
                    float2 uv = i.texcoord + float2(0, y) * _BlitTexture_TexelSize.xy;
                    float4 c  = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                    float gauss = gaussian(_SigmaC, (float)y);

                    col += c * gauss;
                    kernelSum += gauss;
                }

                float3 g = col.rgb / kernelSum;

                float lambda1 = 0.5f * (g.y + g.x + sqrt(g.y * g.y - 2.0f * g.x * g.y + g.x * g.x + 4.0f * g.z * g.z));
                float2 d = float2(g.x - lambda1, g.z);

                return length(d) > 0.0f ?
                    float4(normalize(d), sqrt(lambda1), 1.0f) :
                    float4(0.0f, 1.0f, 0.0f, 1.0f);
            }
            ENDHLSL
        }

        // --- Pass 4: FDoG Blur Pass 1 ------------------------------------------
        Pass
        {
            Name "FDoGBlur1"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float2 t = _TFM.Sample(point_clamp_sampler, i.texcoord).xy;
                float2 n = float2(t.y, -t.x);
                float2 nabs = abs(n);
                float ds = 1.0 / ((nabs.x > nabs.y) ? nabs.x : nabs.y);
                n *= _BlitTexture_TexelSize.xy;

                float2 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).xx;
                float2 kernelSum = 1.0f;

                int kernelSize = (_SigmaE * 2.0f > 1.0f) ? (int)floor(_SigmaE * 2.0f) : 1;

                [loop]
                for (int x = (int)ds; x <= kernelSize; ++x)
                {
                    float fx = (float)x;

                    float gauss1 = gaussian(_SigmaE, fx);
                    float gauss2 = gaussian(_SigmaE * _K, fx);

                    float c1 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord - fx * n).r;
                    float c2 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + fx * n).r;

                    col.r += (c1 + c2) * gauss1;
                    kernelSum.x += 2.0f * gauss1;

                    col.g += (c1 + c2) * gauss2;
                    kernelSum.y += 2.0f * gauss2;
                }

                col /= kernelSum;

                return float4(col, (1.0f + _Tau) * (col.r * 100.0f) - _Tau * (col.g * 100.0f), 1.0f);
            }
            ENDHLSL
        }

        // --- Pass 5: FDoG Blur Pass 2 + Thresholding ---------------------------
        Pass
        {
            Name "FDoGBlur2Threshold"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float kernelSize = _SigmaM * 2.0f;

                float2 w = 1.0f;
                float3 c0 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb;
                float2 G = _CalcDiffBeforeConvolution ? float2(c0.b, 0.0f) : c0.rg;

                float2 v  = _TFM.Sample(point_clamp_sampler, i.texcoord).xy * _BlitTexture_TexelSize.xy;

                float2 st0 = i.texcoord;
                float2 v0  = v;

                [loop]
                for (int d = 1; d < (int)kernelSize; ++d)
                {
                    float fd = (float)d;
                    st0 += v0 * _IntegralConvolutionStepSizes.x;
                    float3 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, st0).rgb;
                    float gauss1 = gaussian(_SigmaM, fd);

                    if (_CalcDiffBeforeConvolution)
                    {
                        G.r += gauss1 * c.b;
                        w.x += gauss1;
                    }
                    else
                    {
                        float gauss2 = gaussian(_SigmaM * _K, fd);

                        G.r += gauss1 * c.r;
                        w.x += gauss1;

                        G.g += gauss2 * c.g;
                        w.y += gauss2;
                    }

                    v0 = _TFM.Sample(point_clamp_sampler, st0).xy * _BlitTexture_TexelSize.xy;
                }

                float2 st1 = i.texcoord;
                float2 v1  = v;

                [loop]
                for (int d = 1; d < (int)kernelSize; ++d)
                {
                    float fd = (float)d;
                    st1 -= v1 * _IntegralConvolutionStepSizes.y;
                    float3 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, st1).rgb;
                    float gauss1 = gaussian(_SigmaM, fd);

                    if (_CalcDiffBeforeConvolution)
                    {
                        G.r += gauss1 * c.b;
                        w.x += gauss1;
                    }
                    else
                    {
                        float gauss2 = gaussian(_SigmaM * _K, fd);

                        G.r += gauss1 * c.r;
                        w.x += gauss1;

                        G.g += gauss2 * c.g;
                        w.y += gauss2;
                    }

                    v1 = _TFM.Sample(point_clamp_sampler, st1).xy * _BlitTexture_TexelSize.xy;
                }

                G /= w;

                float4 D = 0.0f;
                if (_CalcDiffBeforeConvolution)
                {
                    D = G.x;
                }
                else
                {
                    D = (1.0f + _Tau) * (G.r * 100.0f) - _Tau * (G.g * 100.0f);
                }

                float4 output = 0.0f;

                if (_Thresholding == 1)
                {
                    output.r = (D >= _Threshold)  ? 1 : 1 + tanh(_Phi * (D - _Threshold));
                    output.g = (D >= _Threshold2) ? 1 : 1 + tanh(_Phi * (D - _Threshold2));
                    output.b = (D >= _Threshold3) ? 1 : 1 + tanh(_Phi * (D - _Threshold3));
                    output.a = (D >= _Threshold4) ? 1 : 1 + tanh(_Phi * (D - _Threshold4));
                }
                else if (_Thresholding == 2)
                {
                    float a = 1.0f / _Thresholds;
                    float b = _Threshold / 100.0f;
                    float x = D / 100.0f;

                    output = (x >= b) ? 1 : a * floor((pow(x, _Phi) - (a * b / 2.0f)) / (a * b) + 0.5f);
                }
                else if (_Thresholding == 3)
                {
                    float x = D / 100.0f;
                    float qn = floor(x * _Thresholds + 0.5f) / _Thresholds;
                    float qs = smoothstep(-2.0, 2.0, _Phi * (x - qn) * 10.0f) - 0.5f;

                    output = qn + qs / _Thresholds;
                }
                else
                {
                    output = D / 100.0f;
                }

                if (_Invert)
                    output = 1 - output;

                return saturate(output);
            }
            ENDHLSL
        }

        // --- Pass 6: Non-FDoG Blur Pass 1 (separable, horizontal) --------------
        Pass
        {
            Name "NonFDoGBlur1"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float2 col = 0.0f;
                float kernelSum1 = 0.0f;
                float kernelSum2 = 0.0f;

                int kernelSize = (_SigmaE * 2.0f > 2.0f) ? (int)floor(_SigmaE * 2.0f) : 2;

                [loop]
                for (int x = -kernelSize; x <= kernelSize; ++x)
                {
                    float2 uv = i.texcoord + float2(x, 0) * _BlitTexture_TexelSize.xy;
                    float c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).r;

                    float fx = (float)x;
                    float gauss1 = gaussian(_SigmaE, fx);
                    float gauss2 = gaussian(_SigmaE * _K, fx);

                    col.r += c * gauss1;
                    kernelSum1 += gauss1;

                    col.g += c * gauss2;
                    kernelSum2 += gauss2;
                }

                return float4(col.r / kernelSum1, col.g / kernelSum2, 0, 0);
            }
            ENDHLSL
        }

        // --- Pass 7: Non-FDoG Blur Pass 2 (vertical + thresholds) --------------
        Pass
        {
            Name "NonFDoGBlur2"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float2 col = 0.0f;
                float kernelSum1 = 0.0f;
                float kernelSum2 = 0.0f;

                int kernelSize = (_SigmaE * 2.0f > 2.0f) ? (int)floor(_SigmaE * 2.0f) : 2;

                [loop]
                for (int y = -kernelSize; y <= kernelSize; ++y)
                {
                    float2 uv = i.texcoord + float2(0, y) * _BlitTexture_TexelSize.xy;
                    float2 c  = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rg;

                    float fy = (float)y;
                    float gauss1 = gaussian(_SigmaE, fy);
                    float gauss2 = gaussian(_SigmaE * _K, fy);

                    col.r += c.r * gauss1;
                    kernelSum1 += gauss1;

                    col.g += c.g * gauss2;
                    kernelSum2 += gauss2;
                }

                float2 G = float2(col.r / kernelSum1, col.g / kernelSum2);

                float D = (1.0f + _Tau) * (G.r * 100.0f) - _Tau * (G.g * 100.0f);

                float4 output = 0.0f;

                if (_Thresholding == 1)
                {
                    output.r = (D >= _Threshold)  ? 1 : 1 + tanh(_Phi * (D - _Threshold));
                    output.g = (D >= _Threshold2) ? 1 : 1 + tanh(_Phi * (D - _Threshold2));
                    output.b = (D >= _Threshold3) ? 1 : 1 + tanh(_Phi * (D - _Threshold3));
                    output.a = (D >= _Threshold4) ? 1 : 1 + tanh(_Phi * (D - _Threshold4));
                }
                else if (_Thresholding == 2)
                {
                    float a = 1.0f / _Thresholds;
                    float b = _Threshold / 100.0f;
                    float x = D / 100.0f;

                    output = (x >= b) ? 1 : a * floor((pow(x, _Phi) - (a * b / 2.0f)) / (a * b) + 0.5f);
                }
                else if (_Thresholding == 3)
                {
                    float x = D / 100.0f;
                    float qn = floor(x * _Thresholds + 0.5f) / _Thresholds;
                    float qs = smoothstep(-2.0, 2.0, _Phi * (x - qn) * 10.0f) - 0.5f;

                    output = qn + qs / _Thresholds;
                }
                else
                {
                    output = D / 100.0f;
                }

                if (_Invert)
                    output = 1 - output;

                return saturate(output);
            }
            ENDHLSL
        }

        // --- Pass 8: Anti-Aliasing (LIC smoothing along TFM) -------------------
        Pass
        {
            Name "AntiAliasing"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float kernelSize = _SigmaA * 2.0f;

                float4 G = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                float  w = 1.0f;

                float2 v = _TFM.Sample(point_clamp_sampler, i.texcoord).xy * _BlitTexture_TexelSize.xy;

                float2 st0 = i.texcoord;
                float2 v0  = v;

                [loop]
                for (int d = 1; d < (int)kernelSize; ++d)
                {
                    float fd = (float)d;
                    st0 += v0 * _IntegralConvolutionStepSizes.z;
                    float4 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, st0);
                    float  gauss1 = gaussian(_SigmaA, fd);

                    G += gauss1 * c;
                    w += gauss1;

                    v0 = _TFM.Sample(point_clamp_sampler, st0).xy * _BlitTexture_TexelSize.xy;
                }

                float2 st1 = i.texcoord;
                float2 v1  = v;

                [loop]
                for (int d = 1; d < (int)kernelSize; ++d)
                {
                    float fd = (float)d;
                    st1 -= v1 * _IntegralConvolutionStepSizes.w;
                    float4 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, st1);
                    float  gauss1 = gaussian(_SigmaA, fd);

                    G += gauss1 * c;
                    w += gauss1;

                    v1 = _TFM.Sample(point_clamp_sampler, st1).xy * _BlitTexture_TexelSize.xy;
                }

                return G / w;
            }
            ENDHLSL
        }

        // --- Pass 9: Blend / Hatching / Colored Pencil ------------------------
        Pass
        {
            Name "Blend"
            ZWrite Off ZTest Always Blend Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fp

            float4 fp(Varyings i) : SV_Target
            {
                float4 D = SAMPLE_TEXTURE2D(_DogTex, sampler_DogTex, i.texcoord) * _DoGStrength;
                float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb;

                float4 output = 0.0f;

                if (_BlendMode == 0)
                {
                    output.rgb = lerp(_MinColor, _MaxColor, D.r);
                }
                else if (_BlendMode == 1)
                {
                    output.rgb = lerp(_MinColor, col, D.r);
                }
                else if (_BlendMode == 2)
                {
                    if (D.r < 0.5f)
                        output.rgb = lerp(_MinColor, col, D.r * 2.0f);
                    else
                        output.rgb = lerp(col, _MaxColor, (D.r - 0.5f) * 2.0f);
                }

                if (_HatchingEnabled)
                {
                    float2 hatchUV = i.texcoord * 2.0f - 1.0f;

                    float radians = _HatchTexRotation * PI / 180.0f;
                    float2x2 R = {
                        cos(radians), -sin(radians),
                        sin(radians),  cos(radians)
                    };
                    float3 s1 = SAMPLE_TEXTURE2D(
                        _HatchTex,
                        sampler_HatchTex,
                        mul(R, hatchUV * _HatchRes1) * 0.5f + 0.5f
                    ).rgb;

                    output.rgb = lerp(s1, _MaxColor, D.r);

                    if (_EnableSecondLayer)
                    {
                        radians = _HatchTexRotation1 * PI / 180.0f;
                        float2x2 R2 = {
                            cos(radians), -sin(radians),
                            sin(radians),  cos(radians)
                        };
                        float3 s2 = SAMPLE_TEXTURE2D(
                            _HatchTex,
                            sampler_HatchTex,
                            mul(R2, hatchUV * _HatchRes2) * 0.5f + 0.5f
                        ).rgb;

                        output.rgb *= lerp(s2, _MaxColor, D.g);
                    }

                    if (_EnableThirdLayer)
                    {
                        radians = _HatchTexRotation2 * PI / 180.0f;
                        float2x2 R3 = {
                            cos(radians), -sin(radians),
                            sin(radians),  cos(radians)
                        };
                        float3 s3 = SAMPLE_TEXTURE2D(
                            _HatchTex,
                            sampler_HatchTex,
                            mul(R3, hatchUV * _HatchRes3) * 0.5f + 0.5f
                        ).rgb;

                        output.rgb *= lerp(s3, _MaxColor, D.b);
                    }

                    if (_EnableFourthLayer)
                    {
                        radians = _HatchTexRotation3 * PI / 180.0f;
                        float2x2 R4 = {
                            cos(radians), -sin(radians),
                            sin(radians),  cos(radians)
                        };
                        float3 s4 = SAMPLE_TEXTURE2D(
                            _HatchTex,
                            sampler_HatchTex,
                            mul(R4, hatchUV * _HatchRes4) * 0.5f + 0.5f
                        ).rgb;

                        output.rgb *= lerp(s4, _MaxColor, D.a);

                        if (_EnableColoredPencil)
                        {
                            float3 coloredPencil = col + _BrightnessOffset;
                            coloredPencil = lerp(luminance(coloredPencil), coloredPencil, _Saturation);
                            coloredPencil = lerp(coloredPencil, _MaxColor, output.rgb);

                            return float4(lerp(col, coloredPencil, _BlendStrength), 1.0f);
                        }
                    }
                }

                return saturate(float4(lerp(col, output.rgb, _BlendStrength), 1.0f));
            }
            ENDHLSL
        }
    }

    Fallback Off
}
