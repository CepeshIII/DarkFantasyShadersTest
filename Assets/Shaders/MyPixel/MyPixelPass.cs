using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;


internal class MyPixelPass : ScriptableRenderPass
{
    private static readonly int PixelSizeID = Shader.PropertyToID("_pixelSize");

    private const string k_passName = "MyPixelShader";
    private const string k_textureName = "_MainTex";

    private Material material;
    private MyPixelSettings settings;

    private TextureDesc textureDescriptor;



    public MyPixelPass(Material material, MyPixelSettings settings)
    {
        this.material = material;
        this.settings = settings;
    }


    private void UpdateSettings()
    {
        if (material == null) return;

        var volumeComponent =
            VolumeManager.instance.stack.GetComponent<MyPixelVolumeComponent>();

        float PixelSize = volumeComponent.pixelSize.overrideState ?
            volumeComponent.pixelSize.value : settings.pixelSize;

        var samplerFilterType = volumeComponent.samplerFilterType.overrideState ?
            volumeComponent.samplerFilterType.value : settings.samplerFilterType;

        if (samplerFilterType == SamplerFilterType.LinearClamp)
            material.EnableKeyword("_USE_LinearClamp_ON");
        else
            material.DisableKeyword("_USE_LinearClamp_ON");

        material.SetFloat(PixelSizeID, PixelSize);
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
        textureDescriptor = srcCamColor.GetDescriptor(renderGraph);
        textureDescriptor.name = k_textureName;
        textureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(textureDescriptor);

        // Update the blur settings in the material
        UpdateSettings();

        // This check is to avoid an error from the material preview in the scene
        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        // blits from the source texture (camera color in this case)
        // to the destination texture using the first shader pass (the shader pass is defined in the last parameter).
        RenderGraphUtils.BlitMaterialParameters paraVertical = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraVertical, k_passName);

        // Write the processed result back to the camera
        RenderGraphUtils.BlitMaterialParameters paraReturn = new(dst, srcCamColor, material, 0);
        renderGraph.AddBlitPass(paraReturn, "MyPixelShaderReturnPass");
    }
}