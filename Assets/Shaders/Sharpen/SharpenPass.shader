Shader "Hidden/Custom/SharpenPass"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // The Blit.hlsl file provides the vertex shader (Vert),
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

    float _Intensity;

    half4 FragSharpen(Varyings i) : SV_Target
    {
        float2 texel = _BlitTexture_TexelSize.xy;

        // 5-sample sharpen kernel
        half3 center = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb;
        half3 up     = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(0, texel.y)).rgb;
        half3 down   = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord - float2(0, texel.y)).rgb;
        half3 left   = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord - float2(texel.x, 0)).rgb;
        half3 right  = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord + float2(texel.x, 0)).rgb;

        // Unsharp mask technique
        half3 blur = (up + down + left + right + center) / 5.0;
        half3 sharpened = center + (center - blur) * _Intensity;

        return half4(saturate(sharpened), 1);
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
            Name "SharpenPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSharpen
            ENDHLSL
        }
    }
}
