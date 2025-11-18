Shader "Hidden/Shader/OutLinePass2"
{
    Properties
    {
        _Scale("Scale", Float) = 1
        _Color("Color", Color) = (1,.5,.5,1)
        _DepthThreshold("DepthThreshold", Range(0.00004, 0.004)) = 1
        _NormalThreshold("NormalThreshold", Range(0.00004, 1)) = 1
        [KeywordEnum(NORMAL, DEPTH, NORMAL_AND_DEPTH)] _Source ("Outline Source", int) = 0
        _DepthNormalThreshold("_DepthNormalThreshold", Range(0.00004, 1)) = 0
        _DepthNormalThresholdScale("_DepthNormalThresholdScale", Float) = 7


        _Blend1("Blend: Colour -> Depth", Range(0.0, 1.0)) = 1.0
		_Blend2("Blend: Previous -> Outlines", Range(0.0, 1.0)) = 1.0
		_Blend3("Blend: Previous -> Final", Range(0.0, 1.0)) = 1.0
    }


    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

    //#pragma multi_compile _ _ONLY_NORMAL_ON
    #pragma shader_feature _SOURCE_NORMAL _SOURCE_DEPTH _SOURCE_NORMAL_AND_DEPTH


    #if defined(_SOURCE_DEPTH) || defined(_SOURCE_NORMAL_AND_DEPTH)
    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    #endif

    #if defined(_SOURCE_NORMAL) || defined(_SOURCE_NORMAL_AND_DEPTH)
    TEXTURE2D(_CameraNormalsTexture);
    SAMPLER(sampler_CameraNormalsTexture);
    #endif


    float _Scale;
    float4 _Color;
    float _DepthThreshold;
    float _NormalThreshold;
    float _DepthNormalThreshold;
    float _DepthNormalThresholdScale;

    float4x4 _InvCamProjMatrix;

    
	float _Blend1;
	float _Blend2;
	float _Blend3;



    struct CustomVaryings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        float3 positionWS : TEXCOORD1;
        float3 viewSpaceDir   : TEXCOORD2;
        float3 viewVector   : TEXCOORD3;
        UNITY_VERTEX_OUTPUT_STEREO
    };
    

    CustomVaryings CustomVert(Attributes input)
    {
        CustomVaryings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
        float4 posCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);
    
        // Build a clip-space ray (x,y in clip coords, z=1, w=1)
        float4 clipRay = float4(posCS.xy, 1.0, 1.0);

        //float3 viewDir = mul(_ClipToView, clipRay).xyz;  // view-space direction (not normalized)
        float3 viewDir = mul(UNITY_MATRIX_I_P, clipRay).xyz;
        
        viewDir.x = viewDir.x;
        viewDir.y = -viewDir.y;
        
        output.positionCS = posCS;
        output.positionWS = mul(_InvCamProjMatrix, clipRay).xyz;

        output.viewVector = mul(_InvProjMatrix, float4(uv * 2 - 1, 0, -1));
        output.viewVector = mul(UNITY_MATRIX_M, float4(output.viewVector,0));

        output.texcoord = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);
        output.viewSpaceDir = viewDir;
    
        return output;
    }

    

    float4 alphaBlend(float4 top, float4 bottom)
	{
		float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
		float alpha = top.a + bottom.a * (1 - top.a);

		return float4(color, alpha);
	}


    #if defined(_SOURCE_NORMAL) || defined(_SOURCE_NORMAL_AND_DEPTH)

        struct NormalData
        {
            float3 normal0;
            float3 normal1;
            float3 normal2;
            float3 normal3;
        };

        NormalData GetNormalData(float2 bottomLeftUV, float2 topRightUV, float2 bottomRightUV, float2 topLeftUV)
        {
            NormalData normalData = (NormalData)0;

            float3 normal0 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomLeftUV).xyz;
            float3 normal1 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topRightUV).xyz;
            float3 normal2 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomRightUV).xyz;
            float3 normal3 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topLeftUV).xyz;
            
            normalData.normal0 = normal0;
            normalData.normal1 = normal1;
            normalData.normal2 = normal2;
            normalData.normal3 = normal3;

            return normalData;
        }
        
        float NormalEdgeCalculating(NormalData normalData)
        {
            float3 normalFiniteDifference0 = normalData.normal1 - normalData.normal0;
            float3 normalFiniteDifference1 = normalData.normal3 - normalData.normal2;
            float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + 
                            dot(normalFiniteDifference1, normalFiniteDifference1));
            edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;
            return edgeNormal;
        }

        float NormalEdgeCalculating(float2 bottomLeftUV, float2 topRightUV, float2 bottomRightUV, float2 topLeftUV)
        {
            NormalData normalData = GetNormalData(bottomLeftUV, topRightUV, bottomRightUV, topLeftUV);

            return NormalEdgeCalculating(normalData);
        }

    #endif


    #if defined(_SOURCE_DEPTH) || defined(_SOURCE_NORMAL_AND_DEPTH)


    float4 AD(float2 uv)
    {
	
	float4 c = 0.0;
	const int Q = 9;

	float2 s = _Scale * ((1.0 / _ScreenParams.xy) / Q);

	for (int y = -Q + 1; y < Q; y++)
	{
		for (int x = -Q + 1; x < Q; x++)
		{
            float4 uvOffset = float4( uv + (float2(x, y) * s), 0, 0);
			c += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvOffset);
		}
	}

	return c / ((Q * 2 - 1) * (Q * 2 - 1));
	}


        struct DepthData
        {
            float depths[512];
            float averageDepth;
        };



        DepthData GetDepthData(float2 uv)
        {
            DepthData depthData = (DepthData)0;

            int index = 0;
            int depthSum = 0;
            const int Q = 9;

            float2 s = _Scale * ((1.0 / _ScreenParams.xy) / Q);

            [unroll]
            for (int x = -Q + 1; x < Q; x++){
                [unroll]
                for (int y = -Q + 1; y < Q; y++)
                {
                    float2 offsetUV = uv + float2(x, y) * s;
                    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, offsetUV).r;
                    //depth = Linear01Depth(depth, _ZBufferParams);
                    depthData.depths[index] = depth;
                    depthSum += depth;
                    index++;
                }
            }

            //depthData.averageDepth = depthSum / 9.0;
            depthData.averageDepth = depthSum / ((Q * 2 - 1) * (Q * 2 - 1));

            return depthData;
        }


        float3 DepthEdgeCalculating(DepthData depthData, float depthThreshold, float2 uv)
        {
            float d = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv), _ZBufferParams);
		    float ad = Linear01Depth(depthData.averageDepth, _ZBufferParams);


            float3 c = 1.0;
            float4 t = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
            float dt = d > ad - depthThreshold;
            //float dt = step(ad + depthThreshold, d); 
			c = lerp(t, d, 1);
			c = lerp(c, dt, 1);

			c = lerp(c, lerp(_Color, t, dt), 1);
            return c;
            //return depthOutline;
        }


    #endif



    float4 Frag(CustomVaryings i): SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

        float halfScaleFloor = floor(_Scale * 0.5);
        float halfScaleCeil = ceil(_Scale * 0.5);

        float2 bottomLeftUV = i.texcoord - float2(_BlitTexture_TexelSize.x, _BlitTexture_TexelSize.y) * halfScaleFloor;
        float2 topRightUV = i.texcoord + float2(_BlitTexture_TexelSize.x, _BlitTexture_TexelSize.y) * halfScaleCeil;  
        float2 bottomRightUV = i.texcoord + float2(_BlitTexture_TexelSize.x * halfScaleCeil, -_BlitTexture_TexelSize.y * halfScaleFloor);
        float2 topLeftUV = i.texcoord + float2(-_BlitTexture_TexelSize.x * halfScaleFloor, _BlitTexture_TexelSize.y * halfScaleCeil);
        
        float edge = 0;

        #if defined(_SOURCE_NORMAL) || defined(_SOURCE_NORMAL_AND_DEPTH)
            NormalData normalData = GetNormalData(bottomLeftUV, topRightUV, bottomRightUV, topLeftUV);
            float edgeNormal = NormalEdgeCalculating(normalData);
            edge = edgeNormal;
        #endif

        #if defined(_SOURCE_DEPTH)

            float d = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord), _ZBufferParams);
			float ad = Linear01Depth(AD(i.texcoord), _ZBufferParams);

			float dt = d > ad - _DepthThreshold;

			float3 c = 1.0, t = color;

			c = lerp(t, d, _Blend1);
			c = lerp(c, dt, _Blend2);

			c = lerp(c, lerp(_Color.rgb, t, dt), _Blend3);

			return float4(c, 1.0);


            DepthData depthData = GetDepthData(i.texcoord);

            return float4(DepthEdgeCalculating(depthData, _DepthThreshold, i.texcoord), 0);
            //edge = edgeDepth;
        #endif

        #ifdef _SOURCE_NORMAL_AND_DEPTH
            DepthData depthData = GetDepthData(i.texcoord);

            float edgeDepth = DepthEdgeCalculating(depthData, _DepthThreshold, i.texcoord);
            edge = max(edgeNormal, edgeDepth);
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
