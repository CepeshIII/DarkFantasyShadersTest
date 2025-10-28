Shader "Hidden/Custom/HSVPosterization"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // The Blit.hlsl file provides the vertex shader (Vert),
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Assets/Shaders/ColorPalette.hlsl"
    #include "Posterization.hlsl"
    
    #pragma shader_feature _USE_CHANEL_A_ON
    #pragma shader_feature _USE_CHANEL_B_ON
    #pragma shader_feature _USE_CHANEL_C_ON

    #pragma shader_feature _USE_COLOR_PALETTE_ON


    // All components are in the range [0…1], including hue.
    float3 rgb2hsv(float3 c)
    {
        float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
        float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    
        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }


    // All components are in the range [0…1], including hue.
    float3 hsv2rgb(float3 c)
    {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }


    float4 PosterizeColor(float4 color)
    {
        float3 HSV = rgb2hsv(color.rgb);
        float3 result = PosterizeChanels(HSV);
        return float4(hsv2rgb(result), 1);
    }


    half4 FragSharpen(Varyings i) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
        float3 posterizedColor = PosterizeColor(color);

        #if _USE_COLOR_PALETTE_ON
            float3 nearestColor = GetNearestColor(posterizedColor, COLOR_PALETTE_3);
            return float4(nearestColor, 1);
        #endif

        return float4(posterizedColor, 1);
    }                                        
                                             
                                             
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 100
        ZWrite Off Cull Off

        Pass
        {
            Name "MyPosterizationPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSharpen
            ENDHLSL
        }
    }
}
