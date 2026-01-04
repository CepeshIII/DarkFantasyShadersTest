Shader "Custom/ImpostorURP_Octa"
{
    Properties
    {
        [MainTexture] _BaseMap("Color Atlas", 2D) = "white" {}
        [Normal]      _BumpMap("Normal Atlas", 2D) = "bump" {}
                      _ImpostorDepth("Depth Atlas", 2D) = "black" {}

        [MainColor]   _BaseColor("Tint", Color) = (1,1,1,1)

        _Frames("Frames Per Axis (N x N)", Int) = 8
        _DepthScale("Depth Scale (World Units)", Float) = 1.0

        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.33

        // Optional: if your object center != (0,0,0) of the mesh
        _ImpostorOrigin("Impostor Origin (Object Local)", Vector) = (0,0,0,0)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "TransparentCutout"
            "Queue"          = "AlphaTest"
        }

        LOD 200
        Cull Back
        ZWrite On
        ZTest LEqual
        AlphaToMask On

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_BumpMap);        SAMPLER(sampler_BumpMap);
        TEXTURE2D(_ImpostorDepth);  SAMPLER(sampler_ImpostorDepth);

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float  _Frames;
            float  _DepthScale;
            float  _Cutoff;
            float4 _ImpostorOrigin; // local-space origin of the impostor center
        CBUFFER_END


        struct Attributes
        {
            float3 positionOS : POSITION;
            float2 uv         : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0; // uv inside the selected tile
            float3 normalWS   : TEXCOORD1;
        };


        // ============================
        //  HEMI-OCTAHEDRAL FUNCTIONS
        // ============================

        // direction must be normalized
        float2 PyramidUV(float3 direction)
        {
            float3 octant = sign(direction);
            float  sum    = dot(direction, octant);
            float3 o      = direction / sum; // project to octahedron surface

            // Map inner diamond of XY to [0,1]^2 UV square
            float2 uv;
            uv.x = 0.5 * (1.0 + o.x + o.y);
            uv.y = 0.5 * (1.0 + o.y - o.x);
            return uv;
        }

        // OPTIONAL: full-sphere octahedral mapping if you ever need it:
        float2 OctahedronUV(float3 dir)
        {
            dir = normalize(dir);
            float3 n = dir / (abs(dir.x) + abs(dir.y) + abs(dir.z));
            if (n.z < 0.0)
            {
                float2 old = n.xy;
                n.xy = (1.0 - abs(old.yx)) * sign(old.xy);
            }
            return n.xy * 0.5 + 0.5;
        }


        // =========================================
        //  COMMON HELPERS FOR ATLAS FRAME SELECTION
        // =========================================

        struct ImpostorFrameData
        {
            float2 atlasUV;  // final UV to sample atlas
            float3 viewDir;  // world-space direction from origin to camera
        };

        ImpostorFrameData ComputeImpostorFrame(float3 originWS, float2 meshUV)
        {
            ImpostorFrameData data;

            float3 camPosWS = GetCameraPositionWS();
            float3 viewDir  = normalize(camPosWS - originWS);
            data.viewDir    = viewDir;

            // Hemi-octahedra mapping (for "upper hemisphere" around impostor)
            float2 hemiUV = PyramidUV(viewDir);
            hemiUV = saturate(hemiUV); // just in case of tiny numeric issues

            // Convert to frame index in N x N grid
            float N = max(_Frames, 1.0);
            float2 tileSize  = 1.0 / N;

            float2 frameIndex = floor(hemiUV * N);   // integer frame indices

            // Per-frame UV inside tile uses mesh's UV (0..1)
            float2 tileOffset = frameIndex * tileSize;
            float2 atlasUV    = tileOffset + meshUV * tileSize;

            data.atlasUV = atlasUV;
            return data;
        }

        // =================================
        //  VERTEX (with depth parallax push)
        // =================================

        Varyings ImpostorVertex(Attributes IN)
        {
            Varyings OUT;

            // Object to world origin (can be offset by _ImpostorOrigin)
            float3 localOrigin = _ImpostorOrigin.xyz;
            float3 originWS    = TransformObjectToWorld(localOrigin);

            // Compute which frame to use + UV inside atlas
            ImpostorFrameData frame = ComputeImpostorFrame(originWS, IN.uv);

            // Sample depth in vertex stage (Lod 0 is fine)
            float depthSample = SAMPLE_TEXTURE2D_LOD(
                _ImpostorDepth, sampler_ImpostorDepth, frame.atlasUV, 0
            ).r;

            // Convert depthSample (0..1) to world-space offset along viewDir
            float depthOffset = depthSample * _DepthScale;

            // Base vertex position in object space
            float3 posOS = IN.positionOS;

            // Transform to world
            float3 posWS = TransformObjectToWorld(posOS);

            // Push towards camera along viewDir (parallax)
            posWS += frame.viewDir * depthOffset;

            // Output position
            OUT.positionCS = TransformWorldToHClip(posWS);

            // Pass atlas UV
            OUT.uv = frame.atlasUV;

            // Fake "normal" facing camera for simple lighting, or use atlas later
            OUT.normalWS = normalize(-frame.viewDir); // facing camera

            return OUT;
        }

        // ====================
        //  FRAGMENT - FORWARD
        // ====================

        half4 ImpostorFragment(Varyings IN) : SV_Target
        {
            // Sample color
            float4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
            col *= _BaseColor;

            // Alpha clip
            clip(col.a - _Cutoff);

            // Unlit output (you can extend with lighting using IN.normalWS)
            return col;
        }

        ENDHLSL

        // ==========================
        //        FORWARD PASS
        // ==========================
        Pass
        {
            Name "ForwardImpostor"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   ImpostorVertex
            #pragma fragment ImpostorFragment

            // Basic features
            #pragma target 3.0
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            ENDHLSL
        }

    }

    FallBack Off
}
