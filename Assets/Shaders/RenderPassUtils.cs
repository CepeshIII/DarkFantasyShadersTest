using UnityEngine;
using UnityEngine.Rendering;

internal static class RenderPassUtils
{

    // Add a command to create the temporary color copy texture.
    // This method is used in both the render graph system path and the Compatibility Mode path.
    public static void ExecuteCopyColorPass(RasterCommandBuffer cmd, RTHandle sourceTexture)
    {
        Blitter.BlitTexture(cmd, sourceTexture, new Vector4(1, 1, 0, 0), 0.0f, false);
    }


    // Get the texture descriptor needed to create the temporary color copy texture.
    // This method is used in both the render graph system path and the Compatibility Mode path.
    public static RenderTextureDescriptor GetCopyPassTextureDescriptor(RenderTextureDescriptor desc)
    {
        // Avoid an unnecessary multisample anti-aliasing (MSAA) resolve before the main render pass.
        desc.msaaSamples = 1;

        // Avoid copying the depth buffer, as the main pass render in this example doesn't use depth.
        desc.depthBufferBits = (int)DepthBits.None;

        return desc;
    }
}
