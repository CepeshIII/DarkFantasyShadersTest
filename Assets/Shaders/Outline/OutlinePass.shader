Shader "Hidden/Shader/OutLinePass"
{
    Properties
    {
        _Scale("Scale", Float) = 1
        _Color("Color", Color) = (1,.5,.5,1)
        _DepthThreshold("DepthThreshold", Range(0.00004, 0.004)) = 1
        _NormalThreshold("NormalThreshold", Range(0.00004, 1)) = 1
    }


    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

    #pragma multi_compile _ _ONLY_NORMAL_ON


    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    
    TEXTURE2D(_CameraNormalsTexture);
    SAMPLER(sampler_CameraNormalsTexture);


    float _Scale;
    float4 _Color;
    float _DepthThreshold;
    float _NormalThreshold;


    struct CustomVaryings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        float2 viewSpaceDir   : TEXCOORD2;
        UNITY_VERTEX_OUTPUT_STEREO
    };
    
    CustomVaryings CustomVert(Attributes input)
    {
        CustomVaryings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
        float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
        float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);
    
        output.viewSpaceDir = mul(UNITY_MATRIX_MV, pos);
        
        output.positionCS = pos;
        output.texcoord   = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);
    
        return output;
    }

    float4 alphaBlend(float4 top, float4 bottom)
	{
		float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
		float alpha = top.a + bottom.a * (1 - top.a);

		return float4(color, alpha);
	}


    float4 Frag(CustomVaryings i): SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

        float halfScaleFloor = floor(_Scale * 0.5);
        float halfScaleCeil = ceil(_Scale * 0.5);

        float2 bottomLeftUV = i.texcoord - float2(_BlitTexture_TexelSize.x, _BlitTexture_TexelSize.y) * halfScaleFloor;
        float2 topRightUV = i.texcoord + float2(_BlitTexture_TexelSize.x, _BlitTexture_TexelSize.y) * halfScaleCeil;  
        float2 bottomRightUV = i.texcoord + float2(_BlitTexture_TexelSize.x * halfScaleCeil, -_BlitTexture_TexelSize.y * halfScaleFloor);
        float2 topLeftUV = i.texcoord + float2(-_BlitTexture_TexelSize.x * halfScaleFloor, _BlitTexture_TexelSize.y * halfScaleCeil);

        float3 normal0 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomLeftUV);
        float3 normal1 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topRightUV);
        float3 normal2 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomRightUV);
        float3 normal3 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topLeftUV);

        float3 normalFiniteDifference0 = normal1 - normal0;
        float3 normalFiniteDifference1 = normal3 - normal2;
        float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
        edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

        float edge = 0;

        #if _ONLY_NORMAL_ON
            edge = edgeNormal;
        #else
            float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r;
            float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r;
            float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r;
            float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r;

            // Add above the return depth0 line.
            float depthFiniteDifference0 = depth1 - depth0;
            float depthFiniteDifference1 = depth3 - depth2;

            float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100 ;
            edgeDepth = edgeDepth > _DepthThreshold ? 1 : 0;	
            edge = max(edgeDepth, edgeNormal);
        #endif

        float4 edgeColor = float4(_Color.rgb, _Color.a * edge);
        return alphaBlend(edgeColor, color);
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

                #pragma vertex CustomVert
                #pragma fragment Frag
            ENDHLSL
        }
    }
    Fallback Off
}
