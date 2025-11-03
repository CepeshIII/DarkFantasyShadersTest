using UnityEditor.Rendering.LookDev;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using Rendering.AnisotropicKuwahara;





// Anisotropic Kuwahara post effect with RenderGraph, matching your example style.
public sealed class KuwaharaGarrettGunnellRendererFeature : ScriptableRendererFeature
{
    #region FEATURE_FIELDS

    [SerializeField] private Material m_Material; // Shader: "Hidden/AnisotropicKuwahara"
    [SerializeField] private RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    [Header("Kuwahara Settings")]
    [Range(2, 20)] public int kernelSize = 8;
    [Range(1.0f, 18.0f)] public float sharpness = 8f;
    [Range(1.0f, 100.0f)] public float hardness = 8f;
    [Range(0.01f, 2.0f)] public float alpha = 1.0f;
    [Range(0.01f, 2.0f)] public float zeroCrossing = 0.58f;
    [Range(0.01f, 3.0f)] public float zeta = 1.0f;
    public KuwaharaNValues n = KuwaharaNValues.One;
    public KuwaharaTextureScale textureSize = KuwaharaTextureScale.Full;


    public bool useZeta = false;

    [Header("Quality")]
    [Range(1, 4)] public int passes = 1;

    private CustomPostRenderPass m_FullScreenPass;

    #endregion

    #region FEATURE_METHODS

    public override void Create()
    {
#if UNITY_EDITOR
        if (m_Material == null)
        {
            var sh = Shader.Find("Hidden/Custom/Kuwahara/GarrettGunnell/AnisotropicKuwahara");
            if (sh != null) m_Material = new Material(sh);
        }
#endif
        if (m_Material != null)
            m_FullScreenPass = new CustomPostRenderPass(name, m_Material, this);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Material == null || m_FullScreenPass == null) return;
        if (renderingData.cameraData.cameraType == CameraType.Preview ||
            renderingData.cameraData.cameraType == CameraType.Reflection) return;
        if (!renderingData.cameraData.postProcessEnabled) return;

        m_FullScreenPass.renderPassEvent = passEvent;
        m_FullScreenPass.ConfigureInput(ScriptableRenderPassInput.Color);
        renderer.EnqueuePass(m_FullScreenPass);
    }

    protected override void Dispose(bool disposing) { }

    #endregion

    // Create the custom render pass.
    private class CustomPostRenderPass : ScriptableRenderPass
    {
        #region PASS_FIELDS

        private static int k_DefaultSizeDivider = 1;

        private static ProfilingSampler structureTensorProfilingSampler;
        private static ProfilingSampler eigen1ProfilingSampler;
        private static ProfilingSampler eigen2ProfilingSampler;
        private static ProfilingSampler kuwaharaBaseProfilingSampler;
        private static ProfilingSampler kuwaharaAdditionalProfilingSampler;
        private static ProfilingSampler compositeProfilingSampler;

        private readonly Material m_Material;
        private readonly KuwaharaGarrettGunnellRendererFeature m_Feature;

        private static readonly MaterialPropertyBlock s_SharedPropertyBlock = new MaterialPropertyBlock();

        private static readonly bool kSampleActiveColor = true;
        private static readonly bool kBindDepthStencilAttachment = false;

        // Blit.hlsl properties
        private static readonly int kBlitTexturePropertyId = Shader.PropertyToID("_BlitTexture");
        private static readonly int kBlitScaleBiasPropertyId = Shader.PropertyToID("_BlitScaleBias");

        // Kuwahara uniform IDs
        private static readonly int _TFM = Shader.PropertyToID("_TFM");
        private static readonly int _KernelSize = Shader.PropertyToID("_KernelSize");
        private static readonly int _N = Shader.PropertyToID("_N");
        private static readonly int _Q = Shader.PropertyToID("_Q");
        private static readonly int _Hardness = Shader.PropertyToID("_Hardness");
        private static readonly int _Alpha = Shader.PropertyToID("_Alpha");
        private static readonly int _ZeroCrossing = Shader.PropertyToID("_ZeroCrossing");
        private static readonly int _Zeta = Shader.PropertyToID("_Zeta");

        private static readonly string N_1Property = "N_1";
        private static readonly string N_4Property = "N_4";
        private static readonly string N_6Property = "N_6";
        private static readonly string N_8Property = "N_8";


        #endregion

        public CustomPostRenderPass(string passName, Material material, KuwaharaGarrettGunnellRendererFeature feature)
        {
            profilingSampler = new ProfilingSampler(passName);
            m_Material = material;
            m_Feature = feature;

            // We sample active color → require intermediate texture path.
            requiresIntermediateTexture = kSampleActiveColor;


            structureTensorProfilingSampler = new ProfilingSampler($"StructureTensor");
            eigen1ProfilingSampler = new ProfilingSampler($"Eigen1");
            eigen2ProfilingSampler = new ProfilingSampler($"Eigen2");
            kuwaharaBaseProfilingSampler = new ProfilingSampler($"Kuwahara Base");
            kuwaharaAdditionalProfilingSampler = new ProfilingSampler($"Kuwahara Additional");
            compositeProfilingSampler = new ProfilingSampler($"Composite");

        }

        #region PASS_SHARED_RENDERING_CODE

        private static void ExecuteCopyColorPass(RasterCommandBuffer cmd, RTHandle sourceTexture)
        {
            // Your exact Blitter call style
            Blitter.BlitTexture(cmd, sourceTexture, new Vector4(1, 1, 0, 0), 0.0f, false);
        }

        private void ApplyUniforms()
        {
            m_Material.SetInt(_KernelSize, m_Feature.kernelSize);
            m_Material.SetFloat(_Q, m_Feature.sharpness);
            m_Material.SetFloat(_Hardness, m_Feature.hardness);
            m_Material.SetFloat(_Alpha, m_Feature.alpha);
            m_Material.SetFloat(_ZeroCrossing, m_Feature.zeroCrossing);


            m_Material.DisableKeyword(N_1Property);
            m_Material.DisableKeyword(N_4Property);
            m_Material.DisableKeyword(N_6Property);
            m_Material.DisableKeyword(N_8Property);

            switch(m_Feature.n)
            {
                case KuwaharaNValues.One:
                    m_Material.EnableKeyword(N_1Property);
                    break;
                case KuwaharaNValues.Four:
                    m_Material.EnableKeyword(N_4Property);
                    break;
                case KuwaharaNValues.Six:
                    m_Material.EnableKeyword(N_6Property);
                    break;
                case KuwaharaNValues.Eight:
                    m_Material.EnableKeyword(N_8Property);
                    break;
            }

            float z = m_Feature.useZeta
                ? m_Feature.zeta
                : 2.0f / 2.0f / Mathf.Max(1.0f, (m_Feature.kernelSize / 2.0f));
            m_Material.SetFloat(_Zeta, z);
        }

        // Draw a material pass: source in _BlitTexture, optional _TFM, run specific shader passIndex
        private static void ExecuteShaderPass(RasterCommandBuffer cmd, RTHandle src, RTHandle tfmOrNull, Material mat, int passIndex)
        {
            s_SharedPropertyBlock.Clear();

            if (src != null)
                s_SharedPropertyBlock.SetTexture(kBlitTexturePropertyId, src);

            s_SharedPropertyBlock.SetVector(kBlitScaleBiasPropertyId, new Vector4(1, 1, 0, 0));

            if (tfmOrNull != null)
                s_SharedPropertyBlock.SetTexture(_TFM, tfmOrNull);

            // Fullscreen triangle draw
            cmd.DrawProcedural(Matrix4x4.identity, mat, passIndex, MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
        }

        private static RenderTextureDescriptor Downscaled(RenderTextureDescriptor desc)
        {
            // Match your pattern: avoid MSAA and depth for work buffers, and apply divider.
            desc.msaaSamples = 1;
            desc.depthBufferBits = (int)DepthBits.None;
            desc.width = Mathf.Max(1, desc.width / k_DefaultSizeDivider);
            desc.height = Mathf.Max(1, desc.height / k_DefaultSizeDivider);
            return desc;
        }

        #endregion

        #region PASS_RENDER_GRAPH_PATH

        private class DrawPassData
        {
            public Material material;
            public TextureHandle inputTexture;
            public TextureHandle outTexture;
            public TextureHandle tfmTexture; // only used by Kuwahara pass
            public int shaderPass;           // 0,1,2,3
        }

        private class CopyPassData
        {
            public TextureHandle inputTexture;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // Get the resources the pass uses.
            UniversalResourceData resourcesData = frameData.Get<UniversalResourceData>();
            if (!resourcesData.cameraColor.IsValid()) return;

            ApplyUniforms();


            var cameraColorDesc = renderGraph.GetTextureDesc(resourcesData.cameraColor);
            cameraColorDesc.filterMode = FilterMode.Bilinear;
            cameraColorDesc.width = (int)(cameraColorDesc.width * m_Feature.textureSize.ScaleFactor());
            cameraColorDesc.height = (int)(cameraColorDesc.height * m_Feature.textureSize.ScaleFactor());

            var destination = renderGraph.CreateTexture(cameraColorDesc);

            var structureTensor = renderGraph.CreateTexture(destination);
            var eigen1 = renderGraph.CreateTexture(destination);
            var eigen2 = renderGraph.CreateTexture(destination);
            var tmpA = renderGraph.CreateTexture(destination);
            var tmpB = renderGraph.CreateTexture(destination);


            // -------- Pass 0: Structure Tensor (shader pass 0) --------
            using (var p0 = renderGraph.AddRasterRenderPass<DrawPassData>("AK/StructureTensor", out var d0, profilingSampler))
            {
                d0.material = m_Material;
                d0.inputTexture = resourcesData.cameraColor;
                d0.outTexture = structureTensor;
                d0.tfmTexture = TextureHandle.nullHandle;
                d0.shaderPass = 0;

                p0.UseTexture(d0.inputTexture, AccessFlags.Read);
                p0.SetRenderAttachment(d0.outTexture, 0, AccessFlags.Write);

                if (kBindDepthStencilAttachment)
                    p0.UseTexture(resourcesData.cameraDepthTexture, AccessFlags.Read);

                p0.SetRenderFunc((DrawPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, structureTensorProfilingSampler))
                    {
                        ExecuteShaderPass(context.cmd, data.inputTexture, null, data.material, data.shaderPass);
                    }
                });
            }

            // -------- Pass 1: Eigenvectors blur (shader pass 1) --------
            using (var p1 = renderGraph.AddRasterRenderPass<DrawPassData>("AK/Eigen1", out var d1, profilingSampler))
            {
                d1.material = m_Material;
                d1.inputTexture = structureTensor;
                d1.outTexture = eigen1;
                d1.tfmTexture = TextureHandle.nullHandle;
                d1.shaderPass = 1;

                p1.UseTexture(d1.inputTexture, AccessFlags.Read);
                p1.SetRenderAttachment(d1.outTexture, 0, AccessFlags.Write);

                p1.SetRenderFunc((DrawPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, eigen1ProfilingSampler))
                    {
                        ExecuteShaderPass(context.cmd, data.inputTexture, null, data.material, data.shaderPass);
                    }
                });
            }

            // -------- Pass 2: Eigenvectors blur (shader pass 2) --------
            using (var p2 = renderGraph.AddRasterRenderPass<DrawPassData>("AK/Eigen2", out var d2, profilingSampler))
            {
                d2.material = m_Material;
                d2.inputTexture = eigen1;
                d2.outTexture = eigen2;
                d2.tfmTexture = TextureHandle.nullHandle;
                d2.shaderPass = 2;

                p2.UseTexture(d2.inputTexture, AccessFlags.Read);
                p2.SetRenderAttachment(d2.outTexture, 0, AccessFlags.Write);

                p2.SetRenderFunc((DrawPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, eigen2ProfilingSampler))
                    {
                        ExecuteShaderPass(context.cmd, data.inputTexture, null, data.material, data.shaderPass);
                    }
                });
            }

            // -------- Pass 3: Kuwahara base (shader pass 3) ------------
            using (var pk0 = renderGraph.AddRasterRenderPass<DrawPassData>("AK/Kuwahara#0", out var dk0, profilingSampler))
            {
                dk0.material = m_Material;
                dk0.inputTexture = resourcesData.cameraColor;
                dk0.outTexture = tmpA;
                dk0.tfmTexture = eigen2;  // bind _TFM
                dk0.shaderPass = 3;

                pk0.UseTexture(dk0.inputTexture, AccessFlags.Read);
                pk0.UseTexture(dk0.tfmTexture, AccessFlags.Read);
                pk0.SetRenderAttachment(dk0.outTexture, 0, AccessFlags.Write);

                pk0.SetRenderFunc((DrawPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, kuwaharaBaseProfilingSampler))
                    { 
                        // Set _BlitTexture + _TFM via property block and draw shader pass 3
                        s_SharedPropertyBlock.Clear();
                        if (data.inputTexture.IsValid())
                            s_SharedPropertyBlock.SetTexture(kBlitTexturePropertyId, data.inputTexture);
                        s_SharedPropertyBlock.SetVector(kBlitScaleBiasPropertyId, new Vector4(1, 1, 0, 0));
                        s_SharedPropertyBlock.SetTexture(_TFM, data.tfmTexture);

                        context.cmd.DrawProcedural(Matrix4x4.identity, data.material, data.shaderPass,
                            MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
                    }
                });
            }

            // -------- Additional Kuwahara iterations (ping-pong) -------
            int extra = Mathf.Max(0, m_Feature.passes - 1);
            bool aIsSrc = true;

            for (int i = 0; i < extra; i++)
            {
                var src = aIsSrc ? tmpA : tmpB;
                var dst = aIsSrc ? tmpB : tmpA;
                aIsSrc = !aIsSrc;

                using (var pk = renderGraph.AddRasterRenderPass<DrawPassData>($"AK/Kuwahara#{i + 1}", out var dk, profilingSampler))
                {
                    dk.material = m_Material;
                    dk.inputTexture = src;
                    dk.outTexture = dst;
                    dk.tfmTexture = eigen2; // reuse same TFM
                    dk.shaderPass = 3;

                    pk.UseTexture(dk.inputTexture, AccessFlags.Read);
                    pk.UseTexture(dk.tfmTexture, AccessFlags.Read);
                    pk.SetRenderAttachment(dk.outTexture, 0, AccessFlags.Write);

                    pk.SetRenderFunc((DrawPassData data, RasterGraphContext context) =>
                    {
                        using (new ProfilingScope(context.cmd, kuwaharaAdditionalProfilingSampler))
                        {
                            s_SharedPropertyBlock.Clear();
                            if (data.inputTexture.IsValid())
                                s_SharedPropertyBlock.SetTexture(kBlitTexturePropertyId, data.inputTexture);
                            s_SharedPropertyBlock.SetVector(kBlitScaleBiasPropertyId, new Vector4(1, 1, 0, 0));
                            s_SharedPropertyBlock.SetTexture(_TFM, data.tfmTexture);

                            context.cmd.DrawProcedural(Matrix4x4.identity, data.material, data.shaderPass,
                                MeshTopology.Triangles, 3, 1, s_SharedPropertyBlock);
                        }
                    });
                }
            }

            // -------- Composite result to cameraColor -------------------
            var lastTex = aIsSrc ? tmpA : tmpB;

            using (var composite = renderGraph.AddRasterRenderPass<CopyPassData>("AK/Composite", out var copyData, profilingSampler))
            {
                copyData.inputTexture = lastTex;
                composite.UseTexture(copyData.inputTexture, AccessFlags.Read);
                composite.SetRenderAttachment(resourcesData.cameraColor, 0, AccessFlags.Write);

                composite.SetRenderFunc((CopyPassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, compositeProfilingSampler))
                    {
                        // Your exact Blitter call
                        Blitter.BlitTexture(context.cmd, data.inputTexture, new Vector4(1, 1, 0, 0), 0f, false);
                    }
                });
            }

        }

        #endregion
    }
}
