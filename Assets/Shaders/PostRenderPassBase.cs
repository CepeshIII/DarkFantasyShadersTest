using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public abstract class PostRenderPassBase: ScriptableRenderPass
{

    #region PASS_FIELDS

    // Declare the material used to render the post-processing effect.
    protected Material m_Material;

    // Declare a property that enables or disables the render pass that samples the color texture.
    protected bool kSampleActiveColor = true;
    // Declare a property that adds or removes depth-stencil support.
    protected bool kBindDepthStencilAttachment = true;
    // Declare a property that adds or removes normal map support.
    protected bool kBindNormalsTexture = true;

    // Declare a property block to set additional properties for the material.
    protected MaterialPropertyBlock s_SharedPropertyBlock = new MaterialPropertyBlock();

    // Create shader properties in advance, which is more efficient than referencing them by string.
    protected static readonly int kBlitTexturePropertyId = Shader.PropertyToID("_BlitTexture");
    protected static readonly int kBlitScaleBiasPropertyId = Shader.PropertyToID("_BlitScaleBias");

    #endregion


    public PostRenderPassBase(string passName, Material material, ScriptableRenderPassInput renderPassInput)
    {
        // Add a profiling sampler.
        profilingSampler = new ProfilingSampler(passName);

        // Assign the material to the render pass.
        m_Material = material;

        // To make sure the render pass can sample the active color buffer,
        // set URP to render to intermediate textures instead of directly to the backbuffer.
        requiresIntermediateTexture = kSampleActiveColor;

        if ((renderPassInput & ScriptableRenderPassInput.Color) != 0)
            kSampleActiveColor = true;

        if ((renderPassInput & ScriptableRenderPassInput.Depth) != 0)
            kBindDepthStencilAttachment = true;

        if ((renderPassInput & ScriptableRenderPassInput.Normal) != 0)
            kBindNormalsTexture = true;

    }


    // Declare the resources the main render pass uses.
    // This method is used only in the render graph system path.
    protected class MainPassData
    {
        public Material material;
        public TextureHandle inputTexture;
    }


    protected abstract void UpdateVolumeSettings();


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


    #region PASS_RENDER_GRAPH_PATH


    // Add commands to render the effect.
    // This method is used in both the render graph system path and the Compatibility Mode path.
    private void ExecuteMainPass(RasterCommandBuffer cmd, RTHandle sourceTexture, Material material)
    {
        UpdateSettings(sourceTexture);
        // Draw to the current render target.
        cmd.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
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
