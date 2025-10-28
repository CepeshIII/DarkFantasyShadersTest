using UnityEngine;
using UnityEngine.Rendering;
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

}
