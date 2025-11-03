using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;


internal class SharpenPass : ScriptableRenderPass
{
    private static readonly int IntensityID = Shader.PropertyToID("_Intensity");

    private const string k_SharpenPassName = "SharpenPass";
    private const string k_SharpenTextureName = "_SourceTex";

    private Material material;
    private SharpenSettings settings;

    private TextureDesc sharpenTextureDescriptor;



    public SharpenPass(Material material, SharpenSettings settings)
    {
        this.material = material;
        this.settings = settings;
    }


    private void UpdateSettings()
    {
        if (material == null) return;

        var volumeComponent =
            VolumeManager.instance.stack.GetComponent<SharpenVolumeComponent>();

        float intensity = volumeComponent.intensity.overrideState ? 
            volumeComponent.intensity.value : settings.intensity;
        material.SetFloat(IntensityID, intensity);
    }


    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>(); 
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        // The following line ensures that the render pass doesn't blit
        // from the back buffer.
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        sharpenTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
        sharpenTextureDescriptor.name = k_SharpenTextureName;
        sharpenTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(sharpenTextureDescriptor);

        // Update the blur settings in the material
        UpdateSettings();

        // This check is to avoid an error from the material preview in the scene
        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        // blits from the source texture (camera color in this case)
        // to the destination texture using the first shader pass (the shader pass is defined in the last parameter).
        RenderGraphUtils.BlitMaterialParameters paraVertical = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraVertical, k_SharpenPassName);

        // Write the processed result back to the camera
        renderGraph.AddCopyPass(dst, srcCamColor);
    }

}
