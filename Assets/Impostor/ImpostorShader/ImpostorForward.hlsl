     #include "Assets/Impostor/ImpostorShader/Impostor.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"


    TEXTURE2D(_ImpostorDepth);
    SAMPLER(sampler_ImpostorDepth);

    struct CustomVaryings
    {
        Varyings baseVaryings;
        float3 positionVS: TEXCOORD11;
    };
    

    // Used in Standard (Physically Based) shader
    Varyings MyLitPassVertex(Attributes input, Varyings output, 
    VertexPositionInputs vertexInput, VertexNormalInputs normalInput)
    {
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    
        half fogFactor = 0;
        #if !defined(_FOG_FRAGMENT)
            fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
        #endif
    
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    
        // already normalized from normal transform to WS.
        output.normalWS = normalInput.normalWS;
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sign = input.tangentOS.w * GetOddNegativeScale();
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
    
        OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

        OUTPUT_SH4(vertexInput.positionWS, output.normalWS.xyz, GetWorldSpaceNormalizeViewDir(vertexInput.positionWS), output.vertexSH, output.probeOcclusion);
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif
    
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif
    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif
    
        output.positionCS = vertexInput.positionCS;
    
        return output;
    }



    CustomVaryings vert (Attributes v)
    {
        Varyings baseVaryings = (Varyings)0;
            
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_TRANSFER_INSTANCE_ID(v, baseVaryings);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(baseVaryings);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

        float3 offsetWS;
        CalculateOffsetWSForCamera(normalInput.normalWS, vertexInput, offsetWS);

        vertexInput.positionWS += offsetWS;
        vertexInput.positionVS = TransformWorldToView(vertexInput.positionWS);
        vertexInput.positionCS = TransformWorldToHClip(vertexInput.positionWS);

        float4 ndc = vertexInput.positionCS * 0.5f;
        vertexInput.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
        vertexInput.positionNDC.zw = vertexInput.positionCS.zw;

        CustomVaryings output;
        baseVaryings = MyLitPassVertex(v, baseVaryings, vertexInput, normalInput);

        //Varyings baseVaryings = LitPassVertex(v);
        output.baseVaryings = baseVaryings;
        output.positionVS = vertexInput.positionVS.xyz;

        return output;
    }



    struct Output
    {
        float4 color: SV_Target;
        float depth: SV_Depth;
    };


    void InitializeStandardLitSurfaceData(float4 color, float2 uv, inout SurfaceData surfaceData)
    {
        surfaceData.albedo = color.rgb;
        surfaceData.alpha = color.a;
        surfaceData.emission = half3(0, 0, 0);
        surfaceData.metallic = 0;
        surfaceData.occlusion = 1;
        surfaceData.smoothness = 0;
        surfaceData.specular = half3(0, 0, 0);
        surfaceData.clearCoatMask = 0;
        surfaceData.clearCoatSmoothness = 1;
        surfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    }


    float4 ColorCalculating(float4 sampleColor, Varyings input)
    {
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        SurfaceData surfaceData;
        InputData inputData;
        
        InitializeStandardLitSurfaceData(input.uv, surfaceData);

        InitializeInputData(input, surfaceData.normalTS, inputData);
        SETUP_DEBUG_TEXTURE_DATA(inputData, UNDO_TRANSFORM_TEX(input.uv, _BaseMap));

        InitializeBakedGIData(input, inputData);

        half4 color = UniversalFragmentPBR(inputData, surfaceData);
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));
        return color;
    }


    Output frag(CustomVaryings Cinput)
    {
        Varyings input = Cinput.baseVaryings;
        Output output;

        // Depth Calculation
        float sampleDepth = SAMPLE_TEXTURE2D(_ImpostorDepth, sampler_ImpostorDepth, input.uv).r;
        float eyeDepth = -Cinput.positionVS.z; // your quad’s eye-space depth

        float depthOffset = sampleDepth * _DepthScale;
        float eyeModDepth = eyeDepth + depthOffset;
        float nonlinearDepth = EyeDepthToNonLinear(eyeModDepth, _ZBufferParams);

        output.depth = nonlinearDepth;


        // Color Sampling and Lighting
        float4 sampleColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
        float4 color = ColorCalculating(sampleColor, input);

        #ifdef _ALPHATEST_ON
            clip(color.a - _Cutoff);
        #endif

        output.color = color;
        
        return output;
    }