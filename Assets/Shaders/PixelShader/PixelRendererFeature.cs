using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static PixelRendererFeature;


public class PixelRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private PixelSettings settings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader == null)
        {
            shader = Shader.Find("Hidden/Shader/BetterPixelVolume");
        }

        if (shader != null)
        {
            material = new Material(shader);
        }

        if (material != null)
        { 
            renderPass = new CustomPostRenderPass(name, material, scriptableRenderPassInput, settings);
        }
    }

    #endregion


    // Create the custom render pass.
    public class CustomPostRenderPass : PostRenderPassBase
    {
        #region PASS_FIELDS

        private PixelSettings settings;

        protected static readonly int radiusId = Shader.PropertyToID("_Radius");
        protected static readonly int intensityId = Shader.PropertyToID("_Intensity");

        protected static readonly int layer1SizeId = Shader.PropertyToID("_Layer1Size");
        protected static readonly int layer2SizeId = Shader.PropertyToID("_Layer2Size");
        protected static readonly int layer3SizeId = Shader.PropertyToID("_Layer3Size");
        protected static readonly int layer4SizeId = Shader.PropertyToID("_Layer4Size");
        protected static readonly int layer5SizeId = Shader.PropertyToID("_Layer5Size");

        protected static readonly int layerThreshold1Id = Shader.PropertyToID("_LayerThreshold1");
        protected static readonly int layerThreshold2Id = Shader.PropertyToID("_LayerThreshold2");
        protected static readonly int layerThreshold3Id = Shader.PropertyToID("_LayerThreshold3");
        protected static readonly int layerThreshold4Id = Shader.PropertyToID("_LayerThreshold4");
        protected static readonly int layerThreshold5Id = Shader.PropertyToID("_LayerThreshold5");


        #endregion


        public CustomPostRenderPass(string passName, Material material,
            ScriptableRenderPassInput renderPassInput, PixelSettings settings) : base(passName, material, renderPassInput)
        {
            this.settings = settings;
        }

        #region PASS_SHARED_RENDERING_CODE


        protected override void UpdateVolumeSettings()
        {
            if (s_SharedPropertyBlock == null)
                s_SharedPropertyBlock = new MaterialPropertyBlock();

            var volume = VolumeManager.instance.stack?.GetComponent<PixelVolumeComponent>();
            if (volume == null)
                return;

            // --- Fallback logic: use Volume if overridden, else fallback to default settings ---
            var radius = volume.radius.overrideState ? volume.radius.value : settings.radius;
            var intensity = volume.intensity.overrideState ? volume.intensity.value : settings.intensity;

            var layer1 = volume.layer1Size.overrideState ? volume.layer1Size.value : settings.layer1Size;
            var layer2 = volume.layer2Size.overrideState ? volume.layer2Size.value : settings.layer2Size;
            var layer3 = volume.layer3Size.overrideState ? volume.layer3Size.value : settings.layer3Size;
            var layer4 = volume.layer4Size.overrideState ? volume.layer4Size.value : settings.layer4Size;
            var layer5 = volume.layer5Size.overrideState ? volume.layer5Size.value : settings.layer5Size;

            var th1 = volume.layerThreshold1.overrideState ? volume.layerThreshold1.value : settings.layerThreshold1;
            var th2 = volume.layerThreshold2.overrideState ? volume.layerThreshold2.value : settings.layerThreshold2;
            var th3 = volume.layerThreshold3.overrideState ? volume.layerThreshold3.value : settings.layerThreshold3;
            var th4 = volume.layerThreshold4.overrideState ? volume.layerThreshold4.value : settings.layerThreshold4;
            var th5 = volume.layerThreshold5.overrideState ? volume.layerThreshold5.value : settings.layerThreshold5;

            // --- Apply to shader via MaterialPropertyBlock ---
            s_SharedPropertyBlock.SetFloat(radiusId, radius);
            s_SharedPropertyBlock.SetFloat(intensityId, intensity);

            s_SharedPropertyBlock.SetFloat(layer1SizeId, layer1);
            s_SharedPropertyBlock.SetFloat(layer2SizeId, layer2);
            s_SharedPropertyBlock.SetFloat(layer3SizeId, layer3);
            s_SharedPropertyBlock.SetFloat(layer4SizeId, layer4);
            s_SharedPropertyBlock.SetFloat(layer5SizeId, layer5);

            s_SharedPropertyBlock.SetFloat(layerThreshold1Id, th1);
            s_SharedPropertyBlock.SetFloat(layerThreshold2Id, th2);
            s_SharedPropertyBlock.SetFloat(layerThreshold3Id, th3);
            s_SharedPropertyBlock.SetFloat(layerThreshold4Id, th4);
            s_SharedPropertyBlock.SetFloat(layerThreshold5Id, th5);
        }
        #endregion
    }
}

