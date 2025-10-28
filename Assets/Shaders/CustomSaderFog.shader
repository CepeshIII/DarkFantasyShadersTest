//Shader "Custom/URP_StylizedFog"
//{
//    Properties
//    {
//        _FogColor ("Fog Color", Color) = (0.6, 0.8, 0.9, 1)
//        _FogStart ("Fog Start Distance", Float) = 10
//        _FogEnd ("Fog End Distance", Float) = 100
//        _FogHeightStart ("Fog Height Start", Float) = 0
//        _FogHeightEnd ("Fog Height End", Float) = 10
//    }



//    HLSLINCLUDE
    
//    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//    // The Blit.hlsl file provides the vertex shader (Vert),
//    // the input structure (Attributes), and the output structure (Varyings)
//    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
//    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    
//    float4 _FogColor;
//    float _FogStart;
//    float _FogEnd;
//    float _FogHeightStart;
//    float _FogHeightEnd;
    

//    		struct v2f
//		{
//			float2 uv : TEXCOORD0;
//			float4 vertex : SV_POSITION;
//			float4 screenPos : TEXCOORD5;
			
//		};
		
		
//		v2f CustomVert (Attributes v)
//		{
//			v2f o;
//			o.vertex =  GetFullScreenTriangleVertexPosition(v.vertexID);
//			o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
//			o.screenPos = o.vertex;
			
//			return o;
//		}

    
//    float4 MyFrag (Varyings i) : SV_Target
//    {
//        // Get distance from camera
//        float dist = distance(_WorldSpaceCameraPos, i.vertex);
//        float fogByDist = saturate((dist - _FogStart) / (_FogEnd - _FogStart));
    
//        // Get height fog
//        float height = i.vertex.y;
//        float fogByHeight = saturate((height - _FogHeightStart) / (_FogHeightEnd - _FogHeightStart));
    
//        // Combine both (you can experiment with max(), add, etc.)
//        float fogFactor = saturate(fogByDist + fogByHeight * 0.5);
    
//         //Simple surface color (you can use a texture or vertex color instead)
//        float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb;
    
//        float3 finalColor = lerp(baseColor, _FogColor.rgb, fogFactor);
//        return float4(finalColor, 1);
//    }

//    ENDHLSL


//    SubShader
//    {
//        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
//        LOD 100
//        ZWrite Off Cull Off

//        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
//        Pass
//        {
//            Name "ShaderFog"

//            HLSLPROGRAM

//            #pragma vertex CustomVert

//            #pragma fragment MyFrag

//            ENDHLSL

//        }
//    }
//}
