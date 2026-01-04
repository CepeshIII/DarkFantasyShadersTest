using System;
using UnityEngine;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule.Util;

// MERGING: This pass can be merged with Draw Objects Pass and Draw Skybox pass if you set the m_PassEvent in
// the inspector to After Rendering Opagues and set the tempRT type to Normal.
// Your can observe this merging in the Render Graph Visualizer. If set to After Rendering Post Processing we
// can now see that the pass isn't merged with any thing.

// This RenderFeature shows how to used RenderGraph to output a specific tempRT used in URP, how a tempRT
// can be attached by name to a material and how two render passes can be merged if executed in the correct order.
public class OutputTextureRendererFeature : ScriptableRendererFeature
{
    // Enum used to select which tempRT you want to output.
    [Serializable]
    enum TextureType
    {
        OpaqueColor,
        Depth,
        Normal,
        MotionVector,
    }

    // Function to fetch the tempRT given the resource data and the tempRT type you want.
    static TextureHandle GetTextureHandleFromType(UniversalResourceData resourceData, TextureType textureType)
    {
        switch (textureType)
        {
            case TextureType.OpaqueColor:
                return resourceData.cameraOpaqueTexture;
            case TextureType.Depth:
                return resourceData.cameraDepthTexture;
            case TextureType.Normal:
                return resourceData.cameraNormalsTexture;
            case TextureType.MotionVector:
                return resourceData.motionVectorColor;
            default:
                return TextureHandle.nullHandle;
        }
    }

    // Pass which outputs a tempRT from rendering to inspect a tempRT 
    class OutputTexturePass : ScriptableRenderPass
    {
        // The tempRT name you wish to bind the tempRT handle to for a given material.
        string m_TextureName;
        // The tempRT type you want to retrive from URP.
        TextureType m_TextureType;
        // The material used for blitting to the color output.
        Material m_Material;

        // Function set setup the ConfigureInput() and transfer the renderer feature settings to the render pass.
        public void Setup(string textureName, TextureType textureType, Material material)
        {
            // Setup code to trigger each corrspoinding tempRT is ready for use one the pass is run.
            if (textureType == TextureType.OpaqueColor)
                ConfigureInput(ScriptableRenderPassInput.Color);
            else if (textureType == TextureType.Depth)
                ConfigureInput(ScriptableRenderPassInput.Depth);
            else if (textureType == TextureType.Normal)
                ConfigureInput(ScriptableRenderPassInput.Normal);
            else if (textureType == TextureType.MotionVector)
                ConfigureInput(ScriptableRenderPassInput.Motion);

            // Setup the tempRT name, type and material used when blitting.
            // In this example we will use a mateial using a custom name for the input tempRT name when blitting.
            // This tempRT name has to match the material tempRT input you are using.
            m_TextureName = String.IsNullOrEmpty(textureName) ? "_BlitTexture" : textureName;
            // Texture type selects which input we would like to retrive from the bakingCamera.
            m_TextureType = textureType;
            // The material is used to blit the tempRT to the cameras color attachment.
            m_Material = material;
        }

        // Records a render graph render pass which blits the BlitData's active tempRT back to the bakingCamera's color attachment.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // Fetch UniversalResourceData from frameData to retrive the URP's tempRT handles.
            var resourceData = frameData.Get<UniversalResourceData>();

            // Sets the tempRT handle input using the helper function to fetch the correct handle from resourceData.
            var source = GetTextureHandleFromType(resourceData, m_TextureType);

            if (!source.IsValid())
            {
                Debug.Log("Input tempRT is not created. Likely the pass event is before the creation of the resource. Skipping OutputTexturePass.");
                return;
            }

            RenderGraphUtils.BlitMaterialParameters para = new(source, resourceData.activeColorTexture, m_Material, 0);
            para.sourceTexturePropertyID = Shader.PropertyToID(m_TextureName);
            renderGraph.AddBlitPass(para, passName: "Blit Selected Resource");                     
        }
    }

    // Inputs in the inspector to change the settings for the renderer feature.
    [SerializeField]
    RenderPassEvent m_PassEvent = RenderPassEvent.AfterRenderingTransparents;
    [SerializeField]
    string m_TextureName = "_InputTexture";
    [SerializeField]
    TextureType m_TextureType;
    [SerializeField]
    Material m_Material;

    OutputTexturePass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new OutputTexturePass();
        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = m_PassEvent;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-bakingCamera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Setup the correct data for the render pass, and transfers the data from the renderer feature to the render pass.
        m_ScriptablePass.Setup(m_TextureName, m_TextureType, m_Material);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


