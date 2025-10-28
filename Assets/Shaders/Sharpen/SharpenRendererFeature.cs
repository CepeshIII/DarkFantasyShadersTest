using UnityEngine;
using UnityEngine.Rendering.Universal;


internal class SharpenRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private SharpenSettings settings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private SharpenPass renderPass;



    public override void Create()
    {
        if (shader == null)
        {
            return;
        }
        material = new Material(shader);
        renderPass = new SharpenPass(material, settings);
        renderPass.renderPassEvent = passEvent; 
    }
    
    
    public override void AddRenderPasses(ScriptableRenderer renderer,
                                    ref RenderingData renderingData)
    {
        if (material ==null || renderPass == null)
        {
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled)
            return;

        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(renderPass);
        }
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
}