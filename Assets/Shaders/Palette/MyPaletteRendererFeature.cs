using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;



public partial class MyPaletteRendererFeature : ScriptableRendererFeature
{
    
    [SerializeField] private MyPaletteSettings settings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;


    private Material material;
    private MyPalettePass myPass;



    public override void Create()
    {
        if (shader == null)
        {
            shader = Shader.Find("Hidden/Custom/Palette");
        }

        if(shader != null)
            material = new Material(shader);

        if(material != null)
        {
            myPass = new MyPalettePass(material, settings);
            myPass.renderPassEvent = passEvent;
        }

    }


    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        // Skip rendering if m_Material or the pass instance are null.
        if (material == null || myPass == null)
            return;

        // Skip rendering if the camera is outside the custom volume.
        MyPaletteVolumeComponent myVolume = VolumeManager.instance.stack?.GetComponent<MyPaletteVolumeComponent>();
        if (myVolume == null)
            return;

        if (!renderingData.cameraData.postProcessEnabled)
            return;


        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(myPass);
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
