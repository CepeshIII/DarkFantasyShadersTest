using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static MyDitheringRendererFeature;


public class MyDitheringRendererFeature : RendererFeatureBase<CustomPostRenderPass>
{
    #region FEATURE_FIELDS

    [SerializeField]
    private MyDitheringSettings settings;
    
    #endregion

    #region FEATURE_METHODS


    // Override the Create method.
    // Unity calls this method when the Scriptable Renderer Feature loads for the first time,
    // and when you change a property.
    public override void Create()
    {
        if(shader == null)
        {
            shader = Shader.Find("Hidden/Custom/MyDithering");
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
        
        private MyDitheringSettings settings;

        protected static readonly int pixelateId = Shader.PropertyToID("_Pixelate");
        protected static readonly int lerpValueId = Shader.PropertyToID("_LerpValue");

        protected string  bayerLevel2Name = "_BAYER_LEVEL2";
        protected string  bayerLevel4Name = "_BAYER_LEVEL4";
        protected string  bayerLevel8Name = "_BAYER_LEVEL8";

        #endregion


        public CustomPostRenderPass(string passName, Material material, 
            ScriptableRenderPassInput renderPassInput, MyDitheringSettings settings) : base(passName, material, renderPassInput)
        {
            this.settings = settings;
        }


        #region PASS_SHARED_RENDERING_CODE
        protected override void UpdateVolumeSettings()
        {
            var myVolume =
                VolumeManager.instance.stack?.GetComponent<MyDitheringVolumeComponent>();
            if (myVolume == null || m_Material == null)
            {
                return;
            }

            var pixelate = myVolume.pixelate.overrideState ?
                myVolume.pixelate.value : settings.pixelate;

            var lerpValue = myVolume.lerpValue.overrideState ?
                myVolume.lerpValue.value : settings.lerpValue;

            var bayerLevel = myVolume.bayerLevel.overrideState ?
                myVolume.bayerLevel.value : settings.bayerLevel;

            s_SharedPropertyBlock.SetFloat(pixelateId, pixelate);
            s_SharedPropertyBlock.SetFloat(lerpValueId, lerpValue);

            if (m_Material.shader != null)
            {
                // Disable all first to ensure clean state
                m_Material.DisableKeyword(bayerLevel2Name);
                m_Material.DisableKeyword(bayerLevel4Name);
                m_Material.DisableKeyword(bayerLevel8Name);

                switch (bayerLevel)
                {
                    case BayerLevel.Level2:
                        m_Material.EnableKeyword(bayerLevel2Name);
                        break;
                    case BayerLevel.Level4:
                        m_Material.EnableKeyword(bayerLevel4Name);
                        break;
                    case BayerLevel.Level8:
                        m_Material.EnableKeyword(bayerLevel8Name);
                        break;
                }
            }
        }

        #endregion


    }
}
