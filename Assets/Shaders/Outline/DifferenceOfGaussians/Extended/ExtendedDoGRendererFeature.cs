using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;



public class ExtendedDoGRendererFeature :
    RendererFeatureBase<ExtendedDoGRendererFeature.CustomPostRenderPass>
{
    [SerializeField] private ExtendedDoGSettings settings;

    private string FeatureName => "ExtendedDoGRendererFeature";

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("Hidden/ExtendedDoG");

        if (shader != null && (material == null || material.shader != shader))
            material = new Material(shader);

        if (material != null)
            renderPass = new CustomPostRenderPass(
                name, material,
                scriptableRenderPassInput, settings);
    }

    // ============================================================
    // ================= CUSTOM POST RENDER PASS ===================
    // ============================================================
    public class CustomPostRenderPass : PostRenderPassBase
    {
        private ExtendedDoGSettings settings;

        // ------------------------------------
        #region PASS_FIELDS
        // ------------------------------------

        private static ProfilingSampler p_rgb2lab;
        private static ProfilingSampler p_sobel;
        private static ProfilingSampler p_tfm1;
        private static ProfilingSampler p_tfm2;

        private static ProfilingSampler p_fdog1;
        private static ProfilingSampler p_fdog2;
        private static ProfilingSampler p_dog1;
        private static ProfilingSampler p_dog2;

        private static ProfilingSampler p_antialias;
        private static ProfilingSampler p_blend;


        // Property IDs
        private static readonly int SigmaC_ID = Shader.PropertyToID("_SigmaC");
        private static readonly int SigmaE_ID = Shader.PropertyToID("_SigmaE");
        private static readonly int SigmaM_ID = Shader.PropertyToID("_SigmaM");
        private static readonly int SigmaA_ID = Shader.PropertyToID("_SigmaA");

        private static readonly int K_ID = Shader.PropertyToID("_K");
        private static readonly int Tau_ID = Shader.PropertyToID("_Tau");
        private static readonly int Phi_ID = Shader.PropertyToID("_Phi");

        private static readonly int Threshold_ID = Shader.PropertyToID("_Threshold");
        private static readonly int Threshold2_ID = Shader.PropertyToID("_Threshold2");
        private static readonly int Threshold3_ID = Shader.PropertyToID("_Threshold3");
        private static readonly int Threshold4_ID = Shader.PropertyToID("_Threshold4");
        private static readonly int Thresholds_ID = Shader.PropertyToID("_Thresholds");

        private static readonly int BlendStrength_ID = Shader.PropertyToID("_BlendStrength");
        private static readonly int DoGStrength_ID = Shader.PropertyToID("_DoGStrength");

        private static readonly int ConvolutionSteps_ID = Shader.PropertyToID("_IntegralConvolutionStepSizes");
        private static readonly int MinColor_ID = Shader.PropertyToID("_MinColor");
        private static readonly int MaxColor_ID = Shader.PropertyToID("_MaxColor");

        private static readonly int ThresholdMode_ID = Shader.PropertyToID("_Thresholding");
        private static readonly int BlendMode_ID = Shader.PropertyToID("_BlendMode");
        private static readonly int Invert_ID = Shader.PropertyToID("_Invert");
        private static readonly int CalcBeforeConv_ID = Shader.PropertyToID("_CalcDiffBeforeConvolution");

        private static readonly int Hatching_ID = Shader.PropertyToID("_HatchingEnabled");
        private static readonly int HatchTex_ID = Shader.PropertyToID("_HatchTex");

        private static readonly int HatchRes1_ID = Shader.PropertyToID("_HatchRes1");
        private static readonly int HatchRes2_ID = Shader.PropertyToID("_HatchRes2");
        private static readonly int HatchRes3_ID = Shader.PropertyToID("_HatchRes3");
        private static readonly int HatchRes4_ID = Shader.PropertyToID("_HatchRes4");

        private static readonly int HatchRot1_ID = Shader.PropertyToID("_HatchTexRotation");
        private static readonly int HatchRot2_ID = Shader.PropertyToID("_HatchTexRotation1");
        private static readonly int HatchRot3_ID = Shader.PropertyToID("_HatchTexRotation2");
        private static readonly int HatchRot4_ID = Shader.PropertyToID("_HatchTexRotation3");

        private static readonly int Enable2_ID = Shader.PropertyToID("_EnableSecondLayer");
        private static readonly int Enable3_ID = Shader.PropertyToID("_EnableThirdLayer");
        private static readonly int Enable4_ID = Shader.PropertyToID("_EnableFourthLayer");

        private static readonly int ColoredPencil_ID = Shader.PropertyToID("_EnableColoredPencil");
        private static readonly int Brightness_ID = Shader.PropertyToID("_BrightnessOffset");
        private static readonly int Saturation_ID = Shader.PropertyToID("_Saturation");

        private static readonly int TFM_ID = Shader.PropertyToID("_TFM");
        private static readonly int DoGTex_ID = Shader.PropertyToID("_DogTex");

        #endregion
        // ------------------------------------


        public CustomPostRenderPass(
            string passName, Material material,
            ScriptableRenderPassInput input,
            ExtendedDoGSettings settings)
            : base(passName, material, input)
        {
            this.settings = settings;

            p_rgb2lab = new ProfilingSampler("EDoG RGB->LAB");
            p_sobel = new ProfilingSampler("EDoG Sobel ST");
            p_tfm1 = new ProfilingSampler("EDoG TFM Blur 1");
            p_tfm2 = new ProfilingSampler("EDoG TFM Blur 2");

            p_fdog1 = new ProfilingSampler("EDoG FDoG Blur 1");
            p_fdog2 = new ProfilingSampler("EDoG FDoG Blur 2");

            p_dog1 = new ProfilingSampler("EDoG DoG Blur 1");
            p_dog2 = new ProfilingSampler("EDoG DoG Blur 2");

            p_antialias = new ProfilingSampler("EDoG AntiAliasing");
            p_blend = new ProfilingSampler("EDoG Final Blend");

        }

        // ----------------------------------------------------------
        #region PASS_SHARED_RENDERING_CODE
        // ----------------------------------------------------------

        protected override void UpdateVolumeSettings()
        {
            var vol = VolumeManager.instance.stack?.GetComponent<ExtendedDoGVolumeComponent>();
            if (vol == null)
                return;

            // =====================================================
            // Helper: returns actual value (overridden or fallback)
            // (no inline lambdas — everything explicit like example)
            // =====================================================

            // ----------------------
            // FLOW & DEV (floats)
            // ----------------------
            float sigmaC = vol.structureTensorDeviation.overrideState ? vol.structureTensorDeviation.value : settings.structureTensorDeviation;
            float sigmaE = vol.differenceOfGaussiansDeviation.overrideState ? vol.differenceOfGaussiansDeviation.value : settings.differenceOfGaussiansDeviation;
            float sigmaM = vol.lineIntegralDeviation.overrideState ? vol.lineIntegralDeviation.value : settings.lineIntegralDeviation;
            float sigmaA = vol.edgeSmoothDeviation.overrideState ? vol.edgeSmoothDeviation.value : settings.edgeSmoothDeviation;

            // ----------------------
            // K, Sharpness, softThreshold
            // ----------------------
            float stdevScale = vol.stdevScale.overrideState ? vol.stdevScale.value : settings.stdevScale;
            float tau = vol.Sharpness.overrideState ? vol.Sharpness.value : settings.Sharpness;
            float phi = vol.softThreshold.overrideState ? vol.softThreshold.value : settings.softThreshold;

            // ----------------------
            // Thresholds
            // ----------------------
            float whitePoint1 = vol.whitePoint1.overrideState ? vol.whitePoint1.value : settings.whitePoint1;
            float whitePoint2 = vol.whitePoint2.overrideState ? vol.whitePoint2.value : settings.whitePoint2;
            float whitePoint3 = vol.whitePoint3.overrideState ? vol.whitePoint3.value : settings.whitePoint3;
            float whitePoint4 = vol.whitePoint4.overrideState ? vol.whitePoint4.value : settings.whitePoint4;

            int quantizerStep = vol.quantizerStep.overrideState ? vol.quantizerStep.value : settings.quantizerStep;
            int thresholdMode = vol.thresholdMode.overrideState ? vol.thresholdMode.value : (int)settings.thresholdMode;

            // ----------------------
            // Convolution steps
            // ----------------------
            Vector2 convolutionSteps =
                vol.convolutionSteps.overrideState ? vol.convolutionSteps.value : settings.lineConvolutionStepSizes;

            Vector2 smoothSteps =
                vol.smoothSteps.overrideState ? vol.smoothSteps.value : settings.edgeSmoothStepSizes;

            // ----------------------
            // Colors
            // ----------------------
            Vector4 minColor =
                vol.minColor.overrideState ? vol.minColor.value : settings.minColor;
            Vector4 maxColor =
                vol.maxColor.overrideState ? vol.maxColor.value : settings.maxColor;

            // ----------------------
            // Blending
            // ----------------------
            float blendStrength =
                vol.blendStrength.overrideState ? vol.blendStrength.value : settings.blendStrength;

            float dogStrength =
                vol.dogStrength.overrideState ? vol.dogStrength.value : settings.termStrength;

            int blendMode =
                vol.blendMode.overrideState ? vol.blendMode.value : (int)settings.blendMode;

            // ----------------------
            // Hatching flags
            // ----------------------
            bool enableHatching =
                vol.enableHatching.overrideState ? vol.enableHatching.value : settings.enableHatching;

            Texture hatchTexture =
                vol.hatchTex.overrideState ? vol.hatchTex.value : settings.hatchTexture;

            // ----------------------
            // Hatching resolution + rotation per layer
            // ----------------------
            float hatchRes1 = vol.hatchRes1.overrideState ? vol.hatchRes1.value : settings.hatchResolution1;
            float hatchRot1 = vol.hatchRot1.overrideState ? vol.hatchRot1.value : settings.hatchRotation1;

            float hatchRes2 = vol.hatchRes2.overrideState ? vol.hatchRes2.value : settings.hatchResolution2;
            float hatchRot2 = vol.hatchRot2.overrideState ? vol.hatchRot2.value : settings.hatchRotation2;

            float hatchRes3 = vol.hatchRes3.overrideState ? vol.hatchRes3.value : settings.hatchResolution3;
            float hatchRot3 = vol.hatchRot3.overrideState ? vol.hatchRot3.value : settings.hatchRotation3;

            float hatchRes4 = vol.hatchRes4.overrideState ? vol.hatchRes4.value : settings.hatchResolution4;
            float hatchRot4 = vol.hatchRot4.overrideState ? vol.hatchRot4.value : settings.hatchRotation4;

            int enableLayer2 =
                (vol.enableLayer2.overrideState ? vol.enableLayer2.value : settings.enableSecondLayer) ? 1 : 0;
            int enableLayer3 =
                (vol.enableLayer3.overrideState ? vol.enableLayer3.value : settings.enableThirdLayer) ? 1 : 0;
            int enableLayer4 =
                (vol.enableLayer4.overrideState ? vol.enableLayer4.value : settings.enableFourthLayer) ? 1 : 0;

            // ----------------------
            // Colored pencil
            // ----------------------
            int enableColoredPencil =
                (vol.enableColoredPencil.overrideState ? vol.enableColoredPencil.value : settings.enableColoredPencil) ? 1 : 0;

            float brightnessOffset =
                vol.brightnessOffset.overrideState ? vol.brightnessOffset.value : settings.brightnessOffset;

            float saturation =
                vol.saturation.overrideState ? vol.saturation.value : settings.saturation;

            // ----------------------
            // Basic flags
            // ----------------------
            int invert =
                (vol.invert.overrideState ? vol.invert.value : settings.invert) ? 1 : 0;

            int calcBeforeConv =
                (vol.calcDiffBeforeConv.overrideState ? vol.calcDiffBeforeConv.value : settings.calcDiffBeforeConvolution) ? 1 : 0;

            // ========================================================================
            // APPLY SETTINGS TO PROPERTY BLOCK
            // ========================================================================

            // Core sigma settings
            s_SharedPropertyBlock.SetFloat(SigmaC_ID, sigmaC);
            s_SharedPropertyBlock.SetFloat(SigmaE_ID, sigmaE);
            s_SharedPropertyBlock.SetFloat(SigmaM_ID, sigmaM);
            s_SharedPropertyBlock.SetFloat(SigmaA_ID, sigmaA);

            // K/Sharpness/softThreshold
            s_SharedPropertyBlock.SetFloat(K_ID, stdevScale);
            s_SharedPropertyBlock.SetFloat(Tau_ID, tau);
            s_SharedPropertyBlock.SetFloat(Phi_ID, phi);

            // Thresholds
            s_SharedPropertyBlock.SetFloat(Threshold_ID, whitePoint1);
            s_SharedPropertyBlock.SetFloat(Threshold2_ID, whitePoint2);
            s_SharedPropertyBlock.SetFloat(Threshold3_ID, whitePoint3);
            s_SharedPropertyBlock.SetFloat(Threshold4_ID, whitePoint4);

            s_SharedPropertyBlock.SetInt(Thresholds_ID, quantizerStep);
            s_SharedPropertyBlock.SetInt(ThresholdMode_ID, thresholdMode);

            // Convolution
            s_SharedPropertyBlock.SetVector(ConvolutionSteps_ID,
                new Vector4(convolutionSteps.x, convolutionSteps.y, smoothSteps.x, smoothSteps.y));

            // Colors
            s_SharedPropertyBlock.SetVector(MinColor_ID, minColor);
            s_SharedPropertyBlock.SetVector(MaxColor_ID, maxColor);

            // Blending
            s_SharedPropertyBlock.SetFloat(BlendStrength_ID, blendStrength);
            s_SharedPropertyBlock.SetFloat(DoGStrength_ID, dogStrength);
            s_SharedPropertyBlock.SetInt(BlendMode_ID, blendMode);

            // Hatching flags
            s_SharedPropertyBlock.SetInt(Hatching_ID, enableHatching ? 1 : 0);

            if (hatchTexture != null)
                s_SharedPropertyBlock.SetTexture(HatchTex_ID, hatchTexture);

            // Hatching per layer
            s_SharedPropertyBlock.SetFloat(HatchRes1_ID, hatchRes1);
            s_SharedPropertyBlock.SetFloat(HatchRot1_ID, hatchRot1);

            s_SharedPropertyBlock.SetFloat(HatchRes2_ID, hatchRes2);
            s_SharedPropertyBlock.SetFloat(HatchRot2_ID, hatchRot2);

            s_SharedPropertyBlock.SetFloat(HatchRes3_ID, hatchRes3);
            s_SharedPropertyBlock.SetFloat(HatchRot3_ID, hatchRot3);

            s_SharedPropertyBlock.SetFloat(HatchRes4_ID, hatchRes4);
            s_SharedPropertyBlock.SetFloat(HatchRot4_ID, hatchRot4);

            s_SharedPropertyBlock.SetInt(Enable2_ID, enableLayer2);
            s_SharedPropertyBlock.SetInt(Enable3_ID, enableLayer3);
            s_SharedPropertyBlock.SetInt(Enable4_ID, enableLayer4);

            // Colored pencil
            s_SharedPropertyBlock.SetInt(ColoredPencil_ID, enableColoredPencil);
            s_SharedPropertyBlock.SetFloat(Brightness_ID, brightnessOffset);
            s_SharedPropertyBlock.SetFloat(Saturation_ID, saturation);

            // General flags
            s_SharedPropertyBlock.SetInt(Invert_ID, invert);
            s_SharedPropertyBlock.SetInt(CalcBeforeConv_ID, calcBeforeConv);
        }

        #endregion

        // ----------------------------------------------------------
        #region PASS_RENDER_GRAPH_PATH
        // ----------------------------------------------------------

        // Generic full-screen pass (no extra textures)
        private void ExecutePass(RasterCommandBuffer cmd, RTHandle sourceTexture, Material material, int passIndex)
        {
            UpdateSettings(sourceTexture);
            cmd.DrawProcedural(Matrix4x4.identity, material, passIndex,
                MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
        }


        private void ExecutePass(PassData passData, RasterGraphContext context)
        {
            ExecutePass(context.cmd, passData.inputTexture, passData.material, passData.shaderPass);
        }


        // Full-screen pass that also binds TFM as _TFM
        private void ExecutePassWithTFM(RasterCommandBuffer cmd, RTHandle sourceTexture, RTHandle tfmTexture,
            Material material, int passIndex)
        {
            UpdateSettings(sourceTexture);
            s_SharedPropertyBlock.SetTexture(TFM_ID, tfmTexture);
            cmd.DrawProcedural(Matrix4x4.identity, material, passIndex,
                MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
        }


        private void ExecutePassWithTFM(TfmPassData passData, RasterGraphContext context)
        {
            ExecutePassWithTFM(context.cmd, passData.inputTexture, passData.tfmTexture, passData.material, passData.shaderPass);
        }


        // Data containers for RenderGraph passes
        private class PassData
        {
            public Material material;
            public TextureHandle inputTexture;
            public TextureHandle outputTexture;
            public int shaderPass;
        }


        private class TfmPassData
        {
            public Material material;
            public TextureHandle inputTexture;
            public TextureHandle outputTexture;
            public TextureHandle tfmTexture;
            public int shaderPass;
        }


        private class CopyPassData
        {
            public TextureHandle inputTexture;
            public TextureHandle outputTexture;
        }


        private class BlendPassData
        {
            public Material material;
            public TextureHandle cameraColor;
            public TextureHandle dogTexture;
        }


        private class CompositeData
        {
            public TextureHandle inputTexture;
        }


        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var resources = frameData.Get<UniversalResourceData>();

            MatrixCalculating(); // from PostRenderPassBase

            // Get volume to decide pipeline branches
            var vol = VolumeManager.instance.stack.GetComponent<ExtendedDoGVolumeComponent>();

            bool useFlow = vol.useFlow.overrideState ?
                vol.useFlow.value : settings.useFlow;

            bool smoothEdges = vol.smoothEdges.overrideState ?
                vol.smoothEdges.value : settings.smoothEdges;

            // Base descriptor (same size as bakingCamera color)
            var cameraColorDesc = renderGraph.GetTextureDesc(resources.cameraColor);
            cameraColorDesc.filterMode = FilterMode.Bilinear;
            cameraColorDesc.enableRandomWrite = false;

            // Intermediate textures
            var rgbLab = renderGraph.CreateTexture(cameraColorDesc);
            var destination = renderGraph.CreateTexture(cameraColorDesc);

            TextureHandle structureTensor = default;
            TextureHandle eigen1 = default;
            TextureHandle eigen2_TFM = default;

            if (useFlow || smoothEdges)
            {
                structureTensor = renderGraph.CreateTexture(cameraColorDesc);
                eigen1 = renderGraph.CreateTexture(cameraColorDesc);
                eigen2_TFM = renderGraph.CreateTexture(cameraColorDesc);
            }

            var gaussian1 = renderGraph.CreateTexture(cameraColorDesc);
            var gaussian2 = renderGraph.CreateTexture(cameraColorDesc);
            var dogTex = renderGraph.CreateTexture(cameraColorDesc);

            // ======================================================
            // PASS 0: RGB -> LAB
            // ======================================================
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                "EDoG RGB->LAB", out var passData, profilingSampler))
            {
                passData.material = m_Material;
                passData.inputTexture = resources.cameraColor;
                passData.outputTexture = rgbLab;
                passData.shaderPass = 0; // shader pass 0 = RGB->LAB

                builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, p_rgb2lab))
                    {
                        ExecutePass(data, context);
                    }
                });
            }

            // ======================================================
            // PASS 1–3: Edge Tangent Flow (Sobel + TFM blur)
            // Only if useFlow || smoothEdges
            // ======================================================
            if (useFlow && smoothEdges)
            {
                // PASS 1: Structure tensor (Sobel-like)
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                    "EDoG Structure Tensor", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = rgbLab;
                    passData.outputTexture = structureTensor;
                    passData.shaderPass = 1;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_sobel))
                        {
                            ExecutePass(data, context);
                        }
                    });
                }

                // PASS 2: TFM Blur pass 1 (horizontal)
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                    "EDoG TFM Blur 1", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = structureTensor;
                    passData.outputTexture = eigen1;
                    passData.shaderPass = 2;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_tfm1))
                        {
                            ExecutePass(data, context);
                        }
                    });
                }

                // PASS 3: TFM Blur pass 2 (vertical + eigenvectors)
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                    "EDoG TFM Blur 2", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = eigen1;
                    passData.outputTexture = eigen2_TFM;
                    passData.shaderPass = 3;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_tfm2))
                        {
                            ExecutePass(data, context);
                        }
                    });
                }
            }

            // ======================================================
            // PASS 4–5 or 6–7: DoG / FDoG depending on useFlow
            // ======================================================
            if (useFlow)
            {
                // FDoG path uses TFM in shader (_TFM), we bind it via ExecutePassWithTFM

                // PASS 4: FDoG Blur 1
                using (var builder = renderGraph.AddRasterRenderPass<TfmPassData>(
                    "EDoG FDoG Blur 1", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = rgbLab;
                    passData.outputTexture = gaussian1;
                    passData.tfmTexture = eigen2_TFM;
                    passData.shaderPass = 4;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.UseTexture(passData.tfmTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((TfmPassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_fdog1))
                        {
                            ExecutePassWithTFM(data, context);
                        }
                    });
                }

                // PASS 5: FDoG Blur 2
                using (var builder = renderGraph.AddRasterRenderPass<TfmPassData>(
                    "EDoG FDoG Blur 2", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = gaussian1;
                    passData.outputTexture = gaussian2;
                    passData.tfmTexture = eigen2_TFM;
                    passData.shaderPass = 5;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.UseTexture(passData.tfmTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((TfmPassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_fdog2))
                        {
                            ExecutePassWithTFM(data, context);
                        }
                    });
                }
            }
            else
            {
                // Non-flow DoG (separable blur without TFM)

                // PASS 6: Non-FDoG Blur 1 (horizontal)
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                    "EDoG DoG Blur 1", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = rgbLab;
                    passData.outputTexture = gaussian1;
                    passData.shaderPass = 6;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_dog1))
                        {
                            ExecutePass(data, context);
                        }
                    });
                }

                // PASS 7: Non-FDoG Blur 2 (vertical + thresholding)
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                    "EDoG DoG Blur 2", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = gaussian1;
                    passData.outputTexture = gaussian2;
                    passData.shaderPass = 7;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_dog2))
                        {
                            ExecutePass(data, context);
                        }
                    });
                }
            }

            // ======================================================
            // PASS 8: AntiAliasing along flow (LIC) OR simple copy
            // ======================================================
            if (smoothEdges)
            {
                // Anti-aliasing with TFM (_TFM)
                using (var builder = renderGraph.AddRasterRenderPass<TfmPassData>(
                    "EDoG AntiAliasing", out var passData, profilingSampler))
                {
                    passData.material = m_Material;
                    passData.inputTexture = gaussian2;
                    passData.outputTexture = dogTex;
                    passData.tfmTexture = eigen2_TFM;
                    passData.shaderPass = 8;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.UseTexture(passData.tfmTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((TfmPassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_antialias))
                        {
                            ExecutePassWithTFM(data, context);
                        }
                    });
                }
            }
            else
            {
                // Just copy gaussian2 => dogTex
                using (var builder = renderGraph.AddRasterRenderPass<CopyPassData>(
                    "EDoG Copy DoG", out var passData, profilingSampler))
                {
                    passData.inputTexture = gaussian2;
                    passData.outputTexture = dogTex;

                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                    builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                    builder.SetRenderFunc((CopyPassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, p_antialias))
                        {
                            Blitter.BlitTexture(context.cmd, data.inputTexture,
                                new Vector4(1, 1, 0, 0), 0f, false);
                        }
                    });
                }
            }
            

            // ======================================================
            // PASS 9: Final blend (cameraColor + DoG) → cameraColor
            // ======================================================
            using (var builder = renderGraph.AddRasterRenderPass<BlendPassData>(
                "EDoG Final Blend", out var passData, profilingSampler))
            {
                passData.material = m_Material;
                passData.cameraColor = resources.cameraColor;
                passData.dogTexture = dogTex;

                builder.UseTexture(passData.cameraColor, AccessFlags.Read);
                builder.UseTexture(passData.dogTexture, AccessFlags.Read);
                builder.SetRenderAttachment(destination, 0, AccessFlags.Write);

                builder.SetRenderFunc((BlendPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, p_blend))
                    {
                        s_SharedPropertyBlock.Clear();
                        // Bind DoG tempRT
                        s_SharedPropertyBlock.SetTexture(DoGTex_ID, data.dogTexture);
                        // Use cameraColor as the source (for texel size + _BlitTexture / _MainTex)

                        UpdateSettings(data.cameraColor, true);
                        context.cmd.DrawProcedural(Matrix4x4.identity, data.material, 9,
                            MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
                    }
                });
            }

            resources.cameraColor = destination;


        }

        #endregion

    }
}
