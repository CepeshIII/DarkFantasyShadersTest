#ifndef UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED
#define UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED

#define _ALPHATEST_ON

//#include "Assets/LoadedResources/ImpostorTree/ImpostorShader/LitInput.hlsl"
#include "Assets/Impostor/ImpostorShader/Impostor.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _LightDirection;
float3 _LightPosition;


struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    float4 tangentOS     : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    #if defined(_ALPHATEST_ON)
        float2 uv       : TEXCOORD0;
    #endif
    float4 positionCS   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CustomVaryings
{
    Varyings baseVaryings;
    float3 positionVS: TEXCOORD11;
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
    positionCS = ApplyShadowClamping(positionCS);
    return positionCS;
}


CustomVaryings ShadowPassVertex(Attributes input)
{
    //float3 offsetOS;
    //float4 positionVS;
    //CalculateOffsetOSAndPositionVS(input.tangentOS, input.normalOS, input.positionOS, offsetOS, positionVS);

    //input.positionOS += float4(offsetOS, 0);
    
    CustomVaryings output;
    Varyings baseVaryings;

    float3 offsetWS;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    CalculateOffsetWSForLight(normalInput.normalWS, vertexInput, offsetWS);

    float3 positionWS = vertexInput.positionWS + offsetWS;
    input.positionOS = float4(TransformWorldToObject(positionWS), 0);

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, baseVaryings);

    #if defined(_ALPHATEST_ON)
        baseVaryings.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif

    baseVaryings.positionCS = GetShadowPositionHClip(input);

    output.baseVaryings = baseVaryings;
    output.positionVS = TransformWorldToView(positionWS);

    return output;
}


half4 ShadowPassFragment(CustomVaryings input) : SV_TARGET
{
    Varyings baseVaryings = input.baseVaryings;

    UNITY_SETUP_INSTANCE_ID(baseVaryings);

    #if defined(_ALPHATEST_ON)
        Alpha(SampleAlbedoAlpha(baseVaryings.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
        LODFadeCrossFade(baseVaryings.positionCS);
    #endif

    return 0;
}

#endif
