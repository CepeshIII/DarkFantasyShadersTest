using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;


internal class MyPosterizationPass : ScriptableRenderPass
{
    private static readonly int HUE_ID = Shader.PropertyToID("_ChanelA");
    private static readonly int SAT_ID = Shader.PropertyToID("_ChanelB");
    private static readonly int VAL_ID = Shader.PropertyToID("_ChanelC");

    private static readonly int MinChanelAValue_ID = Shader.PropertyToID("_MinChanelAValue");
    private static readonly int MinChanelBValue_ID = Shader.PropertyToID("_MinChanelBValue");
    private static readonly int MinChanelCValue_ID = Shader.PropertyToID("_MinChanelCValue");


    private const string k_PassName = "MyPosterizationPass";
    private const string k_TextureName = "_SourceTex";

    private readonly Material material;
    private readonly MyPosterizationSettings settings;

    private TextureDesc textureDescriptor;



    public MyPosterizationPass(Material material, MyPosterizationSettings settings)
    {
        this.material = material;
        this.settings = settings;
    }


    private void UpdateSettings()
    {
        if (material == null) return;

        var volumeComponent =
            VolumeManager.instance.stack.GetComponent<MyPosterizationVolumeComponent>();

        float ChanelA = volumeComponent.ChanelA.overrideState ?
            volumeComponent.ChanelA.value : settings.ChanelA;

        float ChanelB = volumeComponent.ChanelB.overrideState ?
            volumeComponent.ChanelB.value : settings.ChanelB;

        float ChanelC = volumeComponent.ChanelC.overrideState ?
            volumeComponent.ChanelC.value : settings.ChanelC;

        bool withChanelAPosterization = volumeComponent.withChanelAPosterization.overrideState ?
            volumeComponent.withChanelAPosterization.value : settings.withChanelAPosterization;

        bool withChanelBPosterization = volumeComponent.withChanelBPosterization.overrideState ?
            volumeComponent.withChanelBPosterization.value : settings.withChanelBPosterization;

        bool withChanelCPosterization = volumeComponent.withChanelCPosterization.overrideState ?
            volumeComponent.withChanelCPosterization.value : settings.withChanelCPosterization;

        float minChanelAValue = volumeComponent.MinChanelAValue.overrideState ?
            volumeComponent.MinChanelAValue.value : settings.MinChanelAValue; 
        float minChanelBValue = volumeComponent.MinChanelBValue.overrideState ?
            volumeComponent.MinChanelBValue.value : settings.MinChanelBValue; ;
        float minChanelCValue = volumeComponent.MinChanelCValue.overrideState ?
            volumeComponent.MinChanelCValue.value : settings.MinChanelCValue; 

        bool useColorPalette = volumeComponent.useColorPalette.overrideState ?
            volumeComponent.useColorPalette.value : settings.useColorPalette;

        material.SetFloat(HUE_ID, ChanelA);
        material.SetFloat(SAT_ID, ChanelB);
        material.SetFloat(VAL_ID, ChanelC);

        material.SetFloat(MinChanelAValue_ID, minChanelAValue);
        material.SetFloat(MinChanelBValue_ID, minChanelBValue);
        material.SetFloat(MinChanelCValue_ID, minChanelCValue);

        if (withChanelAPosterization && ChanelA != 0)
            material.EnableKeyword("_USE_CHANEL_A_ON");
        else
            material.DisableKeyword("_USE_CHANEL_A_ON");

        if (withChanelBPosterization && ChanelB != 0)
            material.EnableKeyword("_USE_CHANEL_B_ON");
        else
            material.DisableKeyword("_USE_CHANEL_B_ON");

        if (withChanelCPosterization && ChanelC != 0)
            material.EnableKeyword("_USE_CHANEL_C_ON");
        else
            material.DisableKeyword("_USE_CHANEL_C_ON");

        if(useColorPalette)
            material.EnableKeyword("_USE_COLOR_PALETTE_ON");
        else
            material.DisableKeyword("_USE_COLOR_PALETTE_ON");
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
        textureDescriptor.name = k_TextureName;
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
        renderGraph.AddBlitPass(paraVertical, k_PassName);

        // Write the processed result back to the camera
        RenderGraphUtils.BlitMaterialParameters paraReturn = new(dst, srcCamColor, material, 0);
        renderGraph.AddBlitPass(paraReturn, "MyPosterizationReturnPass");
    }

}
