using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static OutlineRendererFeature;


public class OutlineRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private OutlineSettings outlineSettings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader != null)
        {
            material = new Material(shader);
        }

        if (material != null)
        { 
            renderPass = new CustomPostRenderPass(name, material, scriptableRenderPassInput, outlineSettings);
        }
    }

    #endregion


    // Create the custom render pass.
    public class CustomPostRenderPass : PostRenderPassBase
    {
        #region PASS_FIELDS
        
        private OutlineSettings settings;

        protected static readonly int scaleId = Shader.PropertyToID("_Scale");
        protected static readonly int colorId = Shader.PropertyToID("_Color");
        protected static readonly int depthThresholdId = Shader.PropertyToID("_DepthThreshold");
        protected static readonly int normalThresholdId = Shader.PropertyToID("_NormalThreshold");

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, OutlineSettings outlineSettings) : base(passName, material, renderPassInput)
        {
            settings = outlineSettings;
        }

        #region PASS_SHARED_RENDERING_CODE


        protected override void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<OutlineVolumeComponent>();
            if (myVolume == null)
            {
                return;
            }

            var scale = myVolume.scale.overrideState ?
                myVolume.scale.value : settings.scale;

            var color = myVolume.color.overrideState ?
                myVolume.color.value : settings.color;

            var DepthThreshold = myVolume.DepthThreshold.overrideState ?
                myVolume.DepthThreshold.value : settings.DepthThreshold;

            var NormalThreshold = myVolume.NormalThreshold.overrideState ?
                myVolume.NormalThreshold.value : settings.NormalThreshold;

            var ONLY_NORMAL_ON = myVolume.ONLY_NORMAL_ON.overrideState ?
                myVolume.ONLY_NORMAL_ON.value : settings.ONLY_NORMAL_ON;

            s_SharedPropertyBlock.SetFloat(scaleId, scale);
            s_SharedPropertyBlock.SetColor(colorId, color);
            s_SharedPropertyBlock.SetFloat(depthThresholdId, DepthThreshold);
            s_SharedPropertyBlock.SetFloat(normalThresholdId, NormalThreshold);

            if(ONLY_NORMAL_ON)
                m_Material.EnableKeyword("_ONLY_NORMAL_ON");
            else
                m_Material.DisableKeyword("_ONLY_NORMAL_ON");
        }

        #endregion
    }
}
