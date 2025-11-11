Shader "Hidden/Custom/MyNoiseShader"
{
    Properties
    {
        _Size("Size", Float) = 1
        _LerpValue("LerpValue", Range(0, 1)) = 0
    }


    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    #include "Assets/Shaders/MyShaderFunctions.hlsl"


    float _Size;
    float _LerpValue;

    
    float2 GetHash2D(float2 p)
    {
        return frac(sin(mul(float2x2(0.129898, 0.78233, 0.81314, 0.15926), p)) * 43758.5453);
    }
    
    float2 GetHash2DNormalized(float2 p)
    {
        return normalize(GetHash2D(p) - 0.5);
    }
    
    float PerlinNoise2D(float2 p)
    {
        float2 cell = floor(p);
        const float2 off = float2(0, 1);
        float2 sub = p - cell;
    
        float2 dir_corner00 = GetHash2DNormalized(cell + off.xx);
        float2 dir_corner10 = GetHash2DNormalized(cell + off.yx);
        float2 dir_corner01 = GetHash2DNormalized(cell + off.xy);
        float2 dir_corner11 = GetHash2DNormalized(cell + off.yy);
    
        float grad_corner00 = dot(dir_corner00, off.xx - sub);
        float grad_corner10 = dot(dir_corner10, off.yx - sub);
        float grad_corner01 = dot(dir_corner01, off.xy - sub);
        float grad_corner11 = dot(dir_corner11, off.yy - sub);
    
        float2 quint = sub*sub*sub*(10.0 + sub*(-15.0 + 6.0*sub));
    
        float hor0 = lerp(grad_corner00, grad_corner10, quint.x);
        float hor1 = lerp(grad_corner01, grad_corner11, quint.x);
    
        return lerp(hor0, hor1, quint.y) * 0.7 + 0.5;
    }


    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
        float3 newColor = color * PerlinNoise2D(SquarePixelUvFactor(_BlitTexture_TexelSize.zw) * input.texcoord * _Size);
        
        return float4(lerp(color.rgb, newColor.rgb, _LerpValue), 1);
    }


    ENDHLSL

    SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        ZWrite Off Cull Off ZTest Always

        Pass
        {
            Name "MyNoisePass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }

    Fallback Off
}
