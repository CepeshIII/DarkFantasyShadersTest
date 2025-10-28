Shader "Hidden/Custom/MyPixelShader"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // The Blit.hlsl file provides the vertex shader (Vert),
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Assets/Shaders/MyShaderFunctions.hlsl"

    #pragma multi_compile _ _USE_LinearClamp_ON


    float _pixelSize;

    half4 FragSharpen(Varyings i) : SV_Target
    {
        float2 textureSize = _BlitTexture_TexelSize.zw;
        float minSize = min(textureSize.x, textureSize.y);
        float2 squareUVFactor = textureSize / minSize;
        float2 squaredUV = squareUVFactor * _pixelSize;

        float2 coord ;
        coord.x = round(i.texcoord.x * squaredUV.x) / squaredUV.x;
        coord.y = round(i.texcoord.y * squaredUV.y) / squaredUV.y;

        float3 color;
        #if _USE_LinearClamp_ON
            color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, coord).rgb;
        #else
            color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, coord).rgb;
        #endif

        return half4(color, 1);
       
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
            Name "MyPixelShader"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSharpen
            ENDHLSL
        }
    }
}
