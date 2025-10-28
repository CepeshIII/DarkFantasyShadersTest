using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public enum SamplerFilterType
{
    LinearClamp,
    PointClamp,
}


public partial class MyPixelRendererFeature : ScriptableRendererFeature
{
    
    [SerializeField] private MyPixelSettings settings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;


    private Material material;
    private MyPixelPass myPixelPass;



    public override void Create()
    {
        if (shader == null)
        {
            return;
        }
        material = new Material(shader);
        myPixelPass = new MyPixelPass(material, settings);

        myPixelPass.renderPassEvent = passEvent;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        // Skip rendering if m_Material or the pass instance are null.
        if (material == null || myPixelPass == null)
            return;

        // Skip rendering if the camera is outside the custom volume.
        MyPixelVolumeComponent myVolume = VolumeManager.instance.stack?.GetComponent<MyPixelVolumeComponent>();
        if (myVolume == null)
            return;

        if (!renderingData.cameraData.postProcessEnabled)
            return;


        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(myPixelPass);
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
