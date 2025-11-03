using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;


internal class MyPalettePass : ScriptableRenderPass
{
    private static readonly int LerpValueID = Shader.PropertyToID("_LerpValue");
    private static readonly int PaletteTexID = Shader.PropertyToID("_PaletteTex");

    
    private const string k_passName = "MyPalettePass";
    private const string k_textureName = "_MainTex";

    private Material material;
    private MyPaletteSettings settings;

    private TextureDesc textureDescriptor;



    public MyPalettePass(Material material, MyPaletteSettings settings)
    {
        this.material = material;
        this.settings = settings;
    }


    private void UpdateSettings()
    {
        if (material == null) return;

        var volumeComponent =
            VolumeManager.instance.stack.GetComponent<MyPaletteVolumeComponent>();

        float lerpValue = volumeComponent.lerpValue.overrideState ?
            volumeComponent.lerpValue.value : settings.lerpValue;

        var paletteTex = volumeComponent.rampAtlas.overrideState ?
            volumeComponent.rampAtlas.value : settings.RampTexture;

        if(paletteTex == null) return;

        material.SetFloat(LerpValueID, lerpValue);
        material.SetTexture(PaletteTexID, paletteTex);
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
        RenderGraphUtils.BlitMaterialParameters para = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(para, k_passName);
        renderGraph.AddCopyPass(dst, srcCamColor);
    }
}