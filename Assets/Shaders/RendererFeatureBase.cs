using UnityEngine;
using UnityEngine.Rendering.Universal;

public abstract class RendererFeatureBase<TPass> : ScriptableRendererFeature 
    where TPass : PostRenderPassBase
{
    #region FEATURE_FIELDS

    [SerializeField]
    protected Shader shader;
    [SerializeField] 
    protected RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    [SerializeField]
    protected ScriptableRenderPassInput scriptableRenderPassInput = ScriptableRenderPassInput.Color;

    protected TPass renderPass;
    protected Material material;

    #endregion


    #region FEATURE_METHODS


    // Override the AddRenderPasses method to inject passes into the renderer. Unity calls AddRenderPasses once per camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Skip rendering if m_Material or the pass instance are null.
        if (material == null || renderPass == null)
            return;

        // Skip rendering if the target is a Reflection Probe or a preview camera.
        if (renderingData.cameraData.cameraType == CameraType.Preview
            || renderingData.cameraData.cameraType == CameraType.Reflection)
            return;

        if (!renderingData.cameraData.postProcessEnabled)
            return;

        renderPass.renderPassEvent = passEvent;
        renderPass.ConfigureInput(scriptableRenderPassInput);

        // Add the render pass to the renderer.
        renderer.EnqueuePass(renderPass);
    }


    protected override void Dispose(bool disposing)
    {
        if (Application.isPlaying)
        {
            Destroy(material);
        }
        else
        {
            DestroyImmediate(material);
        }
    }

    #endregion

}
