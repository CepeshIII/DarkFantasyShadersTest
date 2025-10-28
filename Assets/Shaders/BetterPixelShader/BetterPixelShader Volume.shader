Shader "Hidden/Shader/BetterPixelVolume"
{
    Properties
    {
        _Radius("Radius", Range(0, 10)) = 0
        _Intensity("Intensity", Range(0, 1)) = 1
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    float _Intensity;
    float _Radius = 4;




    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        float2 uv = input.texcoord * _BlitScaleBias.xy + _BlitScaleBias.zw;
        half3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb;
    
        half nearestDepth = 1.0h;
        float2 nearestColorUV = uv;
        half2 texel = 1.0h / _ScreenParams.xy;

        [loop]
        for (int u = -_Radius; u <= _Radius; u++)
        {
             [loop]
             for (int v = -_Radius; v <= _Radius; v++)
             {
                  //Get coord of neighbouring pixel for sampling
                  float shiftx = u * texel.x;
                  float shifty = v * texel.y;
                  float2 offset = uv + float2(shiftx, shifty);
        
                  float rawDepth = SAMPLE_TEXTURE2D_LOD(
                         _CameraDepthTexture, 
                         sampler_CameraDepthTexture, 
                         offset, 
                         0
                  ).r;
        
                  float depth = Linear01Depth(rawDepth.r, _ZBufferParams);
                  
                  // Check if the neighbouring pixel is nearest so far - if so, use its value
                  bool nearer = (depth < nearestDepth);
                  nearestDepth = nearer ? depth : nearestDepth;
                  nearestColorUV = nearer ? offset : nearestColorUV;
             }
        }
        half3 nearestColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, nearestColorUV).rgb;
        half3 result = lerp(baseColor, nearestColor, 1);
        return half4(result, 1.0h);
    }


    ENDHLSL

    SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "Better Pixel Volume"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment CustomPostProcess
            ENDHLSL
        }
    }
    Fallback Off
}
