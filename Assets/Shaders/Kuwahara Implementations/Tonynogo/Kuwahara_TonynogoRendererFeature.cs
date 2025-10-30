using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static Kuwahara_TonynogoRendererFeature;


public class Kuwahara_TonynogoRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private Kuwahara_TonynogoSettings settings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader == null)
        {
            shader = Shader.Find("Hidden/Custom/Kuwahara/Tonynogo/OilPaintingURP");
        }

        if(shader != null)
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
        
        private Kuwahara_TonynogoSettings settings;

        protected static readonly int pixelateId = Shader.PropertyToID("_Radius");
        protected static readonly int lerpValueId = Shader.PropertyToID("_LerpValue");

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, Kuwahara_TonynogoSettings settings) : base(passName, material, renderPassInput)
        {
            this.settings = settings;
        }

        #region PASS_SHARED_RENDERING_CODE


        protected override void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<Kuwahara_TonynogoVolumeComponent>();
            if (myVolume == null)
            {
                return;
            }

            var pixelate = myVolume.radius.overrideState ?
                myVolume.radius.value : settings.radius;

            var lerpValue = myVolume.lerpValue.overrideState ?
                myVolume.lerpValue.value : settings.lerpValue;

            s_SharedPropertyBlock.SetFloat(pixelateId, pixelate);
            s_SharedPropertyBlock.SetFloat(lerpValueId, lerpValue);
        }

        #endregion


    }
}
