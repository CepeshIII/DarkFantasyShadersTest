using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static Kuwahara_Daniel_IlettRendererFeature;


public class Kuwahara_Daniel_IlettRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private Kuwahara_Daniel_IlettSettings settings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader == null)
        {
            shader = Shader.Find("Hidden/Custom/Kuwahara/daniel-ilett/PaintingShader");
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
        
        private Kuwahara_Daniel_IlettSettings settings;

        protected static readonly int kernerSizelId = Shader.PropertyToID("_KernelSize");
        protected static readonly int lerpValueId = Shader.PropertyToID("_LerpValue");

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, Kuwahara_Daniel_IlettSettings settings) : base(passName, material, renderPassInput)
        {
            this.settings = settings;
        }

        #region PASS_SHARED_RENDERING_CODE


        protected override void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<Kuwahara_Daniel_IlettVolumeComponent>();
            if (myVolume == null)
            {
                return;
            }

            var pixelate = myVolume.kernelSize.overrideState ?
                myVolume.kernelSize.value : settings.kernelSize;

            var lerpValue = myVolume.lerpValue.overrideState ?
                myVolume.lerpValue.value : settings.lerpValue;

            s_SharedPropertyBlock.SetFloat(kernerSizelId, pixelate);
            s_SharedPropertyBlock.SetFloat(lerpValueId, lerpValue);
        }

        #endregion


    }
}
