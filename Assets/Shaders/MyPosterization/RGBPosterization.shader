Shader "Hidden/Custom/RGBPosterization"
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


    float4 PosterizeColor(float4 color)
    {
        float3 result = PosterizeChanels(color.rgb);
        return float4(result, 1);
    }


    half4 FragSharpen(Varyings i) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
        float4 posterizedColor = PosterizeColor(color);

        #if _USE_COLOR_PALETTE_ON
            float3 nearestColor = GetNearestColor(posterizedColor.rgb, COLOR_PALETTE_3);
            return float4(nearestColor.rgb, 1);
        #endif

        return half4(posterizedColor.rgb, 1);
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
