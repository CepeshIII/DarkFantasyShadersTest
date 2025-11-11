Shader "Hidden/Custom/ImpostorURP_OpaqueAlpha"
{
    Properties
    {
        [MainTexture] _BaseMap("Color Atlas", 2D) = "white" {}
        [Normal] _BumpMap("Normal Atlas", 2D) = "bump" {}
        _ImpostorDepth("Depth Atlas", 2D) = "black" {}
        [MainColor] _BaseColor("_BaseColor", Color) = (1, 1, 1, 1)
        _DepthScale("Depth Scale", Float) = 0.3

        _VertexPushMultiply("Vertex Push Multiply", Float) = 1.0
        _RotationBlend("_RotationBlend", Range(-1, 1)) = 1.0
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.3

        _BumpScale("Normal Scale", Range(-10,10)) = 1

        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _SpecColor("Spec Color", Color) = (0.2,0.2,0.2,1)

        _Surface("Surface", Float) = 0      // 0 = Opaque, 1 = Transparent (URP convention)
        _WorkflowMode("WorkflowMode", Float) = 1.0

        
    }

    HLSLINCLUDE

    #define _ALPHATEST_ON
    #define _NORMALMAP

    

    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            ZWrite On
            ZTest LEqual
            Blend Off
            Cull Back

            HLSLPROGRAM

                #include "Assets/Impostor/ImpostorShader/ImpostorForward.hlsl"

                #pragma vertex vert
                #pragma fragment frag


                // -------------------------------------
                // Material Keywords
                #pragma shader_feature_local _NORMALMAP
                #pragma shader_feature_local _PARALLAXMAP
                #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
                #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
                #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
                #pragma shader_feature_local_fragment _ALPHATEST_ON
                #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
                #pragma shader_feature_local_fragment _EMISSION
                #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
                #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #pragma shader_feature_local_fragment _OCCLUSIONMAP
                #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
                #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
                #pragma shader_feature_local_fragment _SPECULAR_SETUP

                // -------------------------------------
                // Universal Pipeline keywords
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
                #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
                #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
                #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
                #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
                #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
                #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
                #pragma multi_compile_fragment _ _LIGHT_COOKIES
                #pragma multi_compile _ _LIGHT_LAYERS
                #pragma multi_compile _ _FORWARD_PLUS
                #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


                // -------------------------------------
                // Unity defined keywords
                #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
                #pragma multi_compile _ SHADOWS_SHADOWMASK
                #pragma multi_compile _ DIRLIGHTMAP_COMBINED
                #pragma multi_compile _ LIGHTMAP_ON
                #pragma multi_compile _ DYNAMICLIGHTMAP_ON
                #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
                #pragma multi_compile _ LOD_FADE_CROSSFADE
                #pragma multi_compile_fog
                #pragma multi_compile_fragment _ DEBUG_DISPLAY
                #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"

                //--------------------------------------
                // GPU Instancing
                #pragma multi_compile_instancing
                #pragma instancing_options renderinglayer

            ENDHLSL
        }


        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM

            #define _ALPHATEST_ON

            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW


            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            //#include "Assets/LoadedResources/ImpostorTree/ImpostorShader/ImpostorShadow.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }


        
        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex vert
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Assets/Impostor/ImpostorShader/ImpostorLitInput.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            #include "Assets/Impostor/ImpostorShader/ImpostorDepthNormals.hlsl"
            ENDHLSL
        }

    }
}
