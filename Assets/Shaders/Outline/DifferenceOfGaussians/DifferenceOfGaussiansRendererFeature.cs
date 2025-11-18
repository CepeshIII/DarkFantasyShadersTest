using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static DifferenceOfGaussiansRendererFeature;




public class DifferenceOfGaussiansRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private DifferenceOfGaussiansSettings settings;

    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader == null)
        {
            shader = Shader.Find("Hidden/DifferenceOfGaussians");
        }

        if (shader != null || shader != material.shader)
        {
            material = new Material(shader);
        }

        if (material != null)
        { 
            renderPass = new CustomPostRenderPass(name, material, scriptableRenderPassInput, settings);
        }
    }

    #endregion


    // Create the custom render pass.
    public class CustomPostRenderPass : PostRenderPassBase
    {
        #region PASS_FIELDS

        private DifferenceOfGaussiansSettings settings;

        private static ProfilingSampler gaussBlur1ProfilingSampler;
        private static ProfilingSampler gaussBlur2ProfilingSampler;
        private static ProfilingSampler gaussDifferenceProfilingSampler;

        protected static readonly int GaussianKernelSizedId = Shader.PropertyToID("_GaussianKernelSize");
        protected static readonly int ThresholdingId = Shader.PropertyToID("_Thresholding");

        protected static readonly int InvertId = Shader.PropertyToID("_Invert");
        protected static readonly int TanhId = Shader.PropertyToID("_Tanh");

        protected static readonly int SigmaId = Shader.PropertyToID("_Sigma");
        protected static readonly int ThresholdId = Shader.PropertyToID("_Threshold");
        protected static readonly int KId = Shader.PropertyToID("_K");

        protected static readonly int TauId = Shader.PropertyToID("_Tau");
        protected static readonly int PhiId = Shader.PropertyToID("_Phi");

        protected static readonly int colorId = Shader.PropertyToID("_Color");

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, DifferenceOfGaussiansSettings settings) : base(passName, material, renderPassInput)
        {
            this.settings = settings;
            profilingSampler = new ProfilingSampler("DoG");

            gaussBlur1ProfilingSampler = new ProfilingSampler($"DoG/GaussBlur1");
            gaussBlur2ProfilingSampler = new ProfilingSampler($"DoG/GaussBlur2");
            gaussDifferenceProfilingSampler = new ProfilingSampler($"DoG/GaussDifference");
        }

        #region PASS_SHARED_RENDERING_CODE


        protected override void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<DifferenceOfGaussiansVolumeComponent>();
            if (myVolume == null)
            {
                return;
            }

            // Int
            var gaussianKernelSize = myVolume.gaussianKernelSize.overrideState ?
                myVolume.gaussianKernelSize.value : settings.gaussianKernelSize;
            var thresholding = myVolume.thresholding.overrideState ?
                myVolume.thresholding.value : settings.thresholding;
            var invert = myVolume.invert.overrideState ?
                myVolume.invert.value : settings.invert;
            var tanh = myVolume.tanh.overrideState ? 
                myVolume.tanh.value : settings.tanh;

            // Floats
            var sigma = myVolume.Sigma.overrideState ? 
                myVolume.Sigma.value : settings.Sigma;
            var threshold = myVolume.Threshold.overrideState ? 
                myVolume.Threshold.value : settings.Threshold;
            var k = myVolume.K.overrideState ? 
                myVolume.K.value : settings.K;
            var tau = myVolume.Tau.overrideState ? 
                myVolume.Tau.value : settings.Tau;
            var phi = myVolume.Phi.overrideState ? 
                myVolume.Phi.value : settings.Phi;

            // Color
            var color = myVolume.color.overrideState ?
                myVolume.color.value : settings.color;

            s_SharedPropertyBlock.SetInt(GaussianKernelSizedId, gaussianKernelSize);
            s_SharedPropertyBlock.SetInt(ThresholdingId, thresholding);
            s_SharedPropertyBlock.SetInt(InvertId, invert);
            s_SharedPropertyBlock.SetInt(TanhId, tanh);

            s_SharedPropertyBlock.SetFloat(SigmaId, sigma);
            s_SharedPropertyBlock.SetFloat(ThresholdId, threshold);
            s_SharedPropertyBlock.SetFloat(KId, k);
            s_SharedPropertyBlock.SetFloat(TauId, tau);
            s_SharedPropertyBlock.SetFloat(PhiId, phi);

            s_SharedPropertyBlock.SetColor(colorId, color);

        }

        #endregion

        #region PASS_RENDER_GRAPH_PATH


        private void ExecuteBlurPass(RasterCommandBuffer cmd, RTHandle sourceTexture, Material material, int passIndex)
        {
            UpdateSettings(sourceTexture);
            // Draw to the current render target.
            cmd.DrawProcedural(Matrix4x4.identity, material, passIndex, MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
        }


        private void ExecutePass(PassData passData, RasterGraphContext context)
        {
            ExecuteBlurPass(context.cmd, passData.inputTexture, passData.material, passData.shaderPass);
        }


        private class PassData
        {
            public Material material;
            public TextureHandle inputTexture;
            public TextureHandle outputTexture;
            public int shaderPass;
        }


        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData resourcesData = frameData.Get<UniversalResourceData>();

            var cameraColorDesc = renderGraph.GetTextureDesc(resourcesData.cameraColor);
            cameraColorDesc.filterMode = FilterMode.Bilinear;

            var destination = renderGraph.CreateTexture(cameraColorDesc);
            var tempTexure = renderGraph.CreateTexture(destination);

            using (var builder = renderGraph.
                AddRasterRenderPass<PassData>("GaussBlur1", out PassData passData, profilingSampler))
            {
                passData.material = m_Material;
                passData.inputTexture = resourcesData.cameraColor;
                passData.outputTexture = destination;
                passData.shaderPass = 0;

                builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                
                builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) => 
                {
                    using (new ProfilingScope(context.cmd, gaussBlur1ProfilingSampler))
                    {
                        ExecutePass(passData, context);
                    }
                });
            }

            using (var builder = renderGraph.
                AddRasterRenderPass<PassData>("GaussBlur2", out PassData passData, profilingSampler))
            {
                passData.material = m_Material;
                passData.inputTexture = destination;
                passData.outputTexture = tempTexure;
                passData.shaderPass = 1;

                builder.UseTexture(passData.inputTexture, AccessFlags.Read);

                builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, gaussBlur2ProfilingSampler))
                    {
                        ExecutePass(passData, context);
                    }
                });
            }

            using (var builder = renderGraph.
                AddRasterRenderPass<PassData>("DifferenceGauss", out PassData passData, profilingSampler))
            {
                passData.material = m_Material;
                passData.inputTexture = tempTexure;
                passData.outputTexture = destination;
                passData.shaderPass = 2;

                builder.UseTexture(passData.inputTexture, AccessFlags.Read);

                builder.SetRenderAttachment(passData.outputTexture, 0, AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) => 
                {
                    using (new ProfilingScope(context.cmd, gaussDifferenceProfilingSampler))
                    {
                        ExecutePass(passData, context);
                    }
                });
            }

            resourcesData.cameraColor = destination;
        }

        #endregion
    }
}
