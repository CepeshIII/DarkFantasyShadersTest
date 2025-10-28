// File: Hidden/URP/KuwaharaAKF1
// URP full-screen multi-pass version of "ImageFilter/KuwaharaAKF1(Heavy)"
// Requires a renderer feature that:
//   1) Blits cameraColor → SST using Pass "SST"
//   2) Blits SST → SST_BLURRED using Pass "SST_BLUR"
//   3) Blits SST_BLURRED → ScreenTFM using Pass "TFM"
//   4) Blits cameraColor (+ScreenTFM, +K0) → cameraColor using Pass "AKF1"
// Set the *_TexelSize for bound textures (Unity auto-sets for material properties;
// for RTs bound via cmd.SetGlobalTexture, also set the corresponding _TexelSize).

Shader "Hidden/URP/MyKuwaharaAKF1"
{
    Properties
    {
        // Modulator kernel used in the final pass (same as original)
        K0 ("K0: kernel1", 2D) = "white" {}
    }

    SubShader
    {
        Tags{ "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Transparent" }
        Cull Off ZWrite Off ZTest Always Blend Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        // Common varyings from Blit.hlsl:
        //   Attributes, Varyings, Vert(Attributes)

        // Helpers
        inline float2 TexSize(float4 texelSize) { return texelSize.zw; }
        inline float2 Texel(float4 texelSize)   { return texelSize.xy; }


        // Intermediates (you bind them from C# when they are the source for a pass)
        // SST (encoded structure tensor dots in 0..1)
        TEXTURE2D(SST);
        SAMPLER(sampler_SST);
        float4 SST_TexelSize;

        // SST blurred (same encoding as SST)
        TEXTURE2D(SST_BLURRED);
        SAMPLER(sampler_SST_BLURRED);
        float4 SST_BLURRED_TexelSize;

        // Tensor field map (TFM): t.x,t.y, phi, A
        TEXTURE2D(ScreenTFM);
        SAMPLER(sampler_ScreenTFM);
        float4 ScreenTFM_TexelSize;

        // Kernel texture
        TEXTURE2D(K0);
        SAMPLER(sampler_K0);

        // ---- Pass 1: SST (edge detection; encode to 0..1) --------------------
        float4 Frag_SST(Varyings i) : SV_Target
        {
            float2 srcSize = TexSize(_BlitTexture_TexelSize);
            float2 uv      = i.texcoord;
            float2 d       = Texel(_BlitTexture_TexelSize); // = 1/srcSize

            float3 c00 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-d.x,-d.y)).xyz;
            float3 c10 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( 0.0,-d.y)).xyz;
            float3 c20 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( d.x,-d.y)).xyz;

            float3 c01 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-d.x, 0.0)).xyz;
            float3 c11 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).xyz;
            float3 c21 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( d.x, 0.0)).xyz;

            float3 c02 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2(-d.x, d.y)).xyz;
            float3 c12 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( 0.0, d.y)).xyz;
            float3 c22 = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + float2( d.x, d.y)).xyz;

            float3 u = (-1.0*c00 + -2.0*c01 + -1.0*c02
                        +1.0*c20 +  2.0*c21 +  1.0*c22) / 4.0;

            float3 v = (-1.0*c00 + -2.0*c10 + -1.0*c20
                        +1.0*c02 +  2.0*c12 +  1.0*c22) / 4.0;

            float uu = dot(u,u);
            float vv = dot(v,v);
            float uv_ = dot(u,v);

            // encode to 0..1 so we can store in UNorm RTs if needed
            float3 enc = float3(uu, vv, uv_);
            enc = enc * 0.5 + 0.5;
            return float4(enc, 1.0);
        }

        // ---- Pass 2: Blur SST ------------------------------------------------
        // Simple isotropic Gaussian over SST
        float4 Frag_SST_BLUR(Varyings i) : SV_Target
        {
            const float sigma = 2.0;
            float2 srcSize = TexSize(SST_TexelSize);
            float2 uv      = i.texcoord;
            float2 d       = Texel(SST_TexelSize);

            float twoSigma2 = 2.0 * sigma * sigma;
            int halfWidth   = (int)ceil(2.0 * sigma);

            float3 sum = 0.0;
            float norm = 0.0;

            if (halfWidth > 0)
            {
                [loop]
                for (int y = -halfWidth; y <= halfWidth; ++y)
                {
                    [loop]
                    for (int x = -halfWidth; x <= halfWidth; ++x)
                    {
                        float dist = length(float2(x,y));
                        float k = exp(- (dist*dist) / twoSigma2);
                        float3 c = SAMPLE_TEXTURE2D(SST, sampler_SST, uv + float2(x,y) * d).rgb;
                        sum  += k * c;
                        norm += k;
                    }
                }
            }
            else
            {
                sum  = SAMPLE_TEXTURE2D(SST, sampler_SST, uv).rgb;
                norm = 1.0;
            }

            return float4(sum / max(norm, 1e-6), 1.0);
        }

        // ---- Pass 3: TFM (eigen analysis → t, phi, A) -----------------------
        float4 Frag_TFM(Varyings i) : SV_Target
        {
            float2 uv = i.texcoord;
            float3 g  = SAMPLE_TEXTURE2D(SST_BLURRED, sampler_SST_BLURRED, uv).xyz;
            // decode from 0..1 back to signed
            g = g * 2.0 - 1.0;

            float uu = g.x, vv = g.y, uv_ = g.z;

            float root = sqrt(vv*vv - 2.0*uu*vv + uu*uu + 4.0*uv_*uv_);
            float lambda1 = 0.5 * (vv + uu + root);
            float lambda2 = 0.5 * (vv + uu - root);

            float2 v = float2(lambda1 - uu, -uv_);
            float2 t = (length(v) > 0.0) ? normalize(v) : float2(0.0, 1.0);
            float phi = atan2(t.y, t.x);

            float A = (lambda1 + lambda2 > 0.0) ? (lambda1 - lambda2) / (lambda1 + lambda2) : 0.0;

            return float4(t, phi, A);
        }

        // ---- Pass 4: Kuwahara AKF1 ------------------------------------------
        float4 Frag_AKF1(Varyings i) : SV_Target
        {
            // constants (match original)
            const float alpha  = 1.0;
            const int   N      = 8;
            const float radius = 6.0;
            const float q      = 8.0;
            // const float PI     = 3.14159265358979323846;

            float2 uv       = i.texcoord;
            float2 srcSize  = TexSize(_BlitTexture_TexelSize);
            float2 d        = Texel(_BlitTexture_TexelSize);

            // Orientation & anisotropy from TFM
            float4 tfm = SAMPLE_TEXTURE2D(ScreenTFM, sampler_ScreenTFM, uv);
            float phi  = tfm.z;
            float A    = tfm.w;

            float a = radius * clamp((alpha + A) / alpha, 0.1, 2.0);
            float b = radius * clamp(alpha / (alpha + A), 0.1, 2.0);

            float cos_phi = cos(phi);
            float sin_phi = sin(phi);

            float2x2 R = float2x2(cos_phi, -sin_phi,
                                  sin_phi,  cos_phi);
            float2x2 S = float2x2(0.5/a, 0.0,
                                  0.0,   0.5/b);
            float2x2 SR = mul(S, R);

            float piN = 2.0 * PI / float(N);
            float cpn = cos(piN), spn = sin(piN);
            float2x2 X = float2x2(cpn,  spn,
                                  -spn, cpn);

            // determine integer bounds for sampling ellipse
            int max_x = (int)ceil(sqrt(a*a * cos_phi*cos_phi + b*b * sin_phi*sin_phi));
            int max_y = (int)ceil(sqrt(a*a * sin_phi*sin_phi + b*b * cos_phi*cos_phi));

            float4 m[8];
            float3 s_[8];
            [unroll] for (int k = 0; k < N; ++k) { m[k] = 0.0; s_[k] = 0.0; }

            // accumulate per-sector stats
            [loop]
            for (int j = -max_y; j <= max_y; ++j)
            {
                [loop]
                for (int ioff = -max_x; ioff <= max_x; ++ioff)
                {
                    float2 v = mul(SR, float2(ioff, j));
                    if (dot(v, v) <= 0.25)
                    {
                        float2 uvS = uv + float2(ioff, j) * d;
                        // use explicit LOD 0 like original (tex2Dlod → SAMPLE... with LOD not needed here)
                        float3 c = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uvS).rgb;

                        float2 vRot = v;
                        [unroll]
                        for (int k = 0; k < N; ++k)
                        {
                            float2 kUV = float2(0.5, 0.5) + vRot; // center of K0 + offset in [-0.5,0.5]
                            float w = SAMPLE_TEXTURE2D(K0, sampler_K0, kUV).r;

                            m[k] += float4(c * w, w);
                            s_[k] += c * c * w;

                            vRot = mul(X, vRot);
                        }
                    }
                }
            }

            float4 o = 0.0;
            [unroll]
            for (int k = 0; k < N; ++k)
            {
                float wsum = max(m[k].w, 1e-6);
                float3 mean = m[k].rgb / wsum;
                float3 var3 = abs(s_[k] / wsum - mean * mean);
                float sigma2 = var3.r + var3.g + var3.b;
                float w = 1.0 / (1.0 + pow(255.0 * sigma2, 0.5 * q));
                o += float4(mean * w, w);
            }

            return float4(o.rgb / max(o.w, 1e-6), 1.0);
        }
        ENDHLSL

        // ---------- Pass blocks (name them for your renderer feature) ----------
        Pass
        {
            Name "Kuwahara_SST"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag_SST
            ENDHLSL
        }

        Pass
        {
            Name "Kuwahara_SST_BLUR"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag_SST_BLUR
            ENDHLSL
        }

        Pass
        {
            Name "Kuwahara_TFM"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag_TFM
            ENDHLSL
        }

        Pass
        {
            Name "Kuwahara_AKF1"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag_AKF1
            ENDHLSL
        }
    }
}
