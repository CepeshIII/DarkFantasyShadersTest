Shader "Hidden/Custom/Palette"
{
    Properties
    {
        _PaletteTex("Palette Texture", 2D) = "gray" {}
        _LerpValue("LerpValue", Range(0, 1)) = 0
    }


    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    #include "Assets/Shaders/ColorPalette.hlsl"


    TEXTURE2D(_PaletteTex);
    SAMPLER(sampler_PaletteTex);

    float4 _PaletteTex_TexelSize;
    float _LerpValue;



    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);

        float3 nearestColor = lerp(color.rgb, GetNearestColor(color.rgb, 
            _PaletteTex, sampler_PaletteTex, _PaletteTex_TexelSize.z),
            _LerpValue);
        return float4(nearestColor, 1);
    }


    ENDHLSL

    SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "MyPalettePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }

    Fallback Off
}
