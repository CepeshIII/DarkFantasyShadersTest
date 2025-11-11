    #include "Assets/Impostor/ImpostorShader/ImpostorLitInput.hlsl"
    #include "Assets/Impostor/ImpostorShader/Impostor.hlsl"
    //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"


    TEXTURE2D(_ImpostorDepth);
    SAMPLER(sampler_ImpostorDepth);

    
    Varyings CustomDepthNormalsVertex(Attributes input, Varyings output, 
        VertexPositionInputs vertexInput, VertexNormalInputs normalInput)
    {
        #if defined(REQUIRES_UV_INTERPOLATOR)
            output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
        #endif
        output.positionCS = vertexInput.positionCS;
    
        output.normalWS = half3(normalInput.normalWS);
        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            float sign = input.tangentOS.w * float(GetOddNegativeScale());
            half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        #endif
    
        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
            output.tangentWS = tangentWS;
        #endif
    
        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
            half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
            output.viewDirTS = viewDirTS;
        #endif
    
        return output;
    }


    Varyings vert (Attributes input)
    {
        Varyings output = (Varyings)0;
            
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);

        float3 offsetWS;
        CalculateOffsetWSForCamera(normalInput.normalWS, vertexInput, offsetWS);

        vertexInput.positionWS += offsetWS;
        vertexInput.positionVS = TransformWorldToView(vertexInput.positionWS);
        vertexInput.positionCS = TransformWorldToHClip(vertexInput.positionWS);

        float4 ndc = vertexInput.positionCS * 0.5f;
        vertexInput.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
        vertexInput.positionNDC.zw = vertexInput.positionCS.zw;

        output = CustomDepthNormalsVertex(input, output, vertexInput, normalInput);

        return output;
    }

