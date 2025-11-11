    #include "Assets/Impostor/ImpostorShader/ImpostorLitInput.hlsl"

    

    float3 GetOriginWS()
    {
        return TransformObjectToWorld(float3(0, 0, 0 ));
    }


    float LinearDepthToNonLinear(float linear01Depth, float4 zBufferParam){
	    // Inverse of Linear01Depth
	    return (1.0 - (linear01Depth * zBufferParam.y)) / (linear01Depth * zBufferParam.x);
    }
    


    float EyeDepthToNonLinear(float eyeDepth, float4 zBufferParam){
    	// Inverse of LinearEyeDepth
    	return (1.0 - (eyeDepth * zBufferParam.w)) / (eyeDepth * zBufferParam.z);
    }


    float3 CalculatingOffsetWS(float3 normalWS, float3 positionWS, float3 positionVS, float3 lookAtPosition)
    {
        //float3 origin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
        float3 origin = GetOriginWS();
        float3 difference = origin - lookAtPosition;
        difference.y = 0;
        float factor = dot(normalize(difference), normalWS);
        //float factor = saturate(abs(dot(normalize(difference), normalWS)) + 1e-5);

        float3 offsetWS = 0;
        
        if(factor >= _RotationBlend)
        {
            offsetWS = origin - positionWS;
        } 
        else
        {
            float eyeDepth = -positionVS.z; // your quad’s eye-space depth
            float3 directionTo = normalize(lookAtPosition - positionWS);
            offsetWS = directionTo * _VertexPushMultiply * eyeDepth;
        }

        return offsetWS;
    }



    float4 ViewSpaceToObject(float4 positionVS)
    {
        float4 worldPos = mul(UNITY_MATRIX_I_V, positionVS);
        float4 objectPos = mul(unity_WorldToObject, worldPos);
        return objectPos;
    }



    float4 ClipSpaceToObject(float4 positionCS)
    {
        float4 positionVS = mul(UNITY_MATRIX_I_P, positionCS);
        return ViewSpaceToObject(positionVS);
    }


    void CalculateOffsetWSForCamera(float3 normalWS, VertexPositionInputs vertexInput, out float3 offsetWS)
    {
        offsetWS = CalculatingOffsetWS(normalWS, vertexInput.positionWS.xyz, vertexInput.positionVS.xyz, _WorldSpaceCameraPos);
    }

    void CalculateOffsetWSForLight(float3 normalWS, VertexPositionInputs vertexInput, out float3 offsetWS)
    {
        offsetWS = CalculatingOffsetWS(normalWS, vertexInput.positionWS.xyz, vertexInput.positionVS.xyz, _MainLightPosition);
    }
