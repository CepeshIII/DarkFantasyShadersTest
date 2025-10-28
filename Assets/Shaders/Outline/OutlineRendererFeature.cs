using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static OutlineRendererFeature;


public class OutlineRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private OutlineSettings outlineSettings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader != null)
        {
            material = new Material(shader);
        }

        if (material != null)
        { 
            renderPass = new CustomPostRenderPass(name, material, scriptableRenderPassInput, outlineSettings);
        }
    }

    #endregion


    // Create the custom render pass.
    public class CustomPostRenderPass : PostRenderPassBase
    {
        #region PASS_FIELDS
        
        private OutlineSettings settings;

        protected static readonly int scaleId = Shader.PropertyToID("_Scale");
        protected static readonly int colorId = Shader.PropertyToID("_Color");
        protected static readonly int depthThresholdId = Shader.PropertyToID("_DepthThreshold");
        protected static readonly int normalThresholdId = Shader.PropertyToID("_NormalThreshold");

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, OutlineSettings outlineSettings) : base(passName, material, renderPassInput)
        {
            settings = outlineSettings;
        }

        #region PASS_SHARED_RENDERING_CODE


        private void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<OutlineVolumeComponent>();
            if (myVolume == null)
            {
                return;
            }

            var scale = myVolume.scale.overrideState ?
                myVolume.scale.value : settings.scale;

            var color = myVolume.color.overrideState ?
                myVolume.color.value : settings.color;

            var DepthThreshold = myVolume.DepthThreshold.overrideState ?
                myVolume.DepthThreshold.value : settings.DepthThreshold;

            var NormalThreshold = myVolume.NormalThreshold.overrideState ?
                myVolume.NormalThreshold.value : settings.NormalThreshold;

            var ONLY_NORMAL_ON = myVolume.ONLY_NORMAL_ON.overrideState ?
                myVolume.ONLY_NORMAL_ON.value : settings.ONLY_NORMAL_ON;

            s_SharedPropertyBlock.SetFloat(scaleId, scale);
            s_SharedPropertyBlock.SetColor(colorId, color);
            s_SharedPropertyBlock.SetFloat(depthThresholdId, DepthThreshold);
            s_SharedPropertyBlock.SetFloat(normalThresholdId, NormalThreshold);

            if(ONLY_NORMAL_ON)
                m_Material.EnableKeyword("_ONLY_NORMAL_ON");
            else
                m_Material.DisableKeyword("_ONLY_NORMAL_ON");
        }


        private void UpdateSettings(RTHandle sourceTexture)
        {
            // Clear the material properties.
            s_SharedPropertyBlock.Clear();
            if (sourceTexture != null)
                s_SharedPropertyBlock.SetTexture(kBlitTexturePropertyId, sourceTexture);

            // Set the scale and bias so shaders that use Blit.hlsl work correctly.
            s_SharedPropertyBlock.SetVector(kBlitScaleBiasPropertyId, new Vector4(1, 1, 0, 0));

            UpdateVolumeSettings();
        }


        // Add commands to render the effect.
        // This method is used in both the render graph system path and the Compatibility Mode path.
        private void ExecuteMainPass(RasterCommandBuffer cmd, RTHandle sourceTexture, Material material)
        {
            UpdateSettings(sourceTexture);
            // Draw to the current render target.
            cmd.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
        }

        #endregion


        #region PASS_RENDER_GRAPH_PATH

        // Declare the resources the main render pass uses.
        // This method is used only in the render graph system path.
        private class MainPassData
        {
            public Material material;
            public TextureHandle inputTexture;
        }


        private void ExecuteMainPass(MainPassData data, RasterGraphContext context)
        {
            ExecuteMainPass(context.cmd, data.inputTexture.IsValid() ? data.inputTexture : null, data.material);
        }


        // Override the RecordRenderGraph method to implement the rendering logic.
        // This method is used only in the render graph system path.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // Get the resources the pass uses.
            UniversalResourceData resourcesData = frameData.Get<UniversalResourceData>();
            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
            MainPassData passData;

            // Sample from the current color texture.
            using (var builder = renderGraph.
                AddRasterRenderPass<MainPassData>(passName, out passData, profilingSampler))
            {
                passData.material = m_Material;
                TextureHandle destination;

                // Copy cameraColor to a temporary texture, if the kSampleActiveColor property is set to true. 
                if (kSampleActiveColor)
                {
                    var cameraColorDesc = renderGraph.GetTextureDesc(resourcesData.cameraColor);
                    cameraColorDesc.name = "_CameraColorCustomPostProcessing";
                    cameraColorDesc.clearBuffer = false;

                    destination = renderGraph.CreateTexture(cameraColorDesc);
                    passData.inputTexture = resourcesData.cameraColor;

                    // If you use framebuffer fetch in your material, use builder.SetInputAttachment to reduce GPU bandwidth usage and power consumption. 
                    builder.UseTexture(passData.inputTexture, AccessFlags.Read);
                }
                else
                {
                    destination = resourcesData.cameraColor;
                    passData.inputTexture = TextureHandle.nullHandle;
                }

                // Set the render graph to render to the temporary texture.
                builder.SetRenderAttachment(destination, 0, AccessFlags.Write);

                // Bind the depth-stencil buffer.
                // This is a demonstration. The code isn't used in the example.
                if (kBindDepthStencilAttachment)
                {
                    builder.UseTexture(resourcesData.cameraDepthTexture, AccessFlags.Read);
                }

                if (kBindNormalsTexture)
                {
                    builder.UseTexture(resourcesData.cameraNormalsTexture, AccessFlags.Read);
                }

                // Set the render method.
                builder.SetRenderFunc((MainPassData data, RasterGraphContext context)
                    => ExecuteMainPass(data, context));

                // Set cameraColor to the new temporary texture so the next render pass can use it.
                // You don't need to blit to and from cameraColor if you use the render graph system.
                if (kSampleActiveColor)
                {
                    resourcesData.cameraColor = destination;
                }
            }
        }
        #endregion
    }
}
