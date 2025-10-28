using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using static Unity.Burst.Intrinsics.X86;

public sealed class KuwaharaRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private Material m_Material;
    [SerializeField] private RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    [SerializeField] private int sizeDivider = 1;

    private KuwaharaPass m_Pass;

    public override void Create()
    {
        if (m_Material != null)
            m_Pass = new KuwaharaPass(name, m_Material, sizeDivider);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_Material == null || m_Pass == null)
            return;

        if (renderingData.cameraData.cameraType == CameraType.Preview ||
            renderingData.cameraData.cameraType == CameraType.Reflection)
            return;

        m_Pass.renderPassEvent = passEvent;
        renderer.EnqueuePass(m_Pass);
    }

    private class KuwaharaPass : ScriptableRenderPass
    {
        private readonly Material m_Material;
        private readonly int m_SizeDivider;
        private readonly ProfilingSampler m_Sampler;

        public KuwaharaPass(string name, Material mat, int divider)
        {
            m_Material = mat;
            m_SizeDivider = Mathf.Max(1, divider);
            m_Sampler = new ProfilingSampler(name);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData res = frameData.Get<UniversalResourceData>();
            UniversalCameraData cam = frameData.Get<UniversalCameraData>();

            var desc = renderGraph.GetTextureDesc(res.cameraColor);
            desc.depthBufferBits = 0;
            desc.width /= m_SizeDivider;
            desc.height /= m_SizeDivider;
            desc.clearBuffer = false;
            desc.filterMode = FilterMode.Bilinear;

            var descSST = new TextureDesc(desc);
            descSST.name = "Kuwahara_SST";

            var descSST_Blurred = new TextureDesc(desc);
            descSST_Blurred.name = "Kuwahara_SST_BLURR";

            var desctfm = new TextureDesc(desc);
            desctfm.name = "Kuwahara_TFM";

            var desctAkfOut = new TextureDesc(desc);
            desctAkfOut.name = "AkfOut";

            // Create intermediate RTs
            TextureHandle sst = renderGraph.CreateTexture(descSST);
            TextureHandle sstBlurred = renderGraph.CreateTexture(descSST_Blurred);
            TextureHandle tfm = renderGraph.CreateTexture(desctfm);
            TextureHandle akfOut = renderGraph.CreateTexture(desctAkfOut);
            

            // --- Pass 1: SST ---
            using (var pass = renderGraph.AddRasterRenderPass<PassData>("Kuwahara_SST", out var data, m_Sampler))
            {
                data.mat = m_Material;
                data.src = res.cameraColor;
                data.dst = sst;
                data.passIndex = m_Material.FindPass("Kuwahara_SST");

                pass.UseTexture(data.src, AccessFlags.Read);
                pass.SetRenderAttachment(data.dst, 0, AccessFlags.Write);
                pass.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    BlitFullScreen(ctx.cmd, d.mat, d.passIndex, d.src);
                });
            }

            // --- Pass 2: SST_BLUR ---
            using (var pass = renderGraph.AddRasterRenderPass<PassData>("Kuwahara_SST_BLUR", out var data, m_Sampler))
            {
                data.mat = m_Material;
                data.src = sst;
                data.dst = sstBlurred;
                data.passIndex = m_Material.FindPass("Kuwahara_SST_BLUR");

                pass.UseTexture(data.src, AccessFlags.Read);
                pass.SetRenderAttachment(data.dst, 0, AccessFlags.Write);
                pass.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    BlitFullScreen(ctx.cmd, d.mat, d.passIndex, d.src);
                });
            }

            // --- Pass 3: TFM ---
            using (var pass = renderGraph.AddRasterRenderPass<PassData>("Kuwahara_TFM", out var data, m_Sampler))
            {
                data.mat = m_Material;
                data.src = sstBlurred;
                data.dst = tfm;
                data.passIndex = m_Material.FindPass("Kuwahara_TFM");

                pass.UseTexture(data.src, AccessFlags.Read);
                pass.SetRenderAttachment(data.dst, 0, AccessFlags.Write);
                pass.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    BlitFullScreen(ctx.cmd, d.mat, d.passIndex, d.src);
                });
            }

            // --- Pass 4: AKF1 (final composition) ---
            using (var pass = renderGraph.AddRasterRenderPass<PassData>("Kuwahara_AKF1", out var data, m_Sampler))
            {
                data.mat = m_Material;
                data.src = res.cameraColor;
                data.dst = akfOut;
                data.passIndex = m_Material.FindPass("Kuwahara_AKF1");

                // Bind intermediates as globals
                pass.UseTexture(tfm, AccessFlags.Read);
                pass.UseTexture(sstBlurred, AccessFlags.Read);
                pass.UseTexture(data.src, AccessFlags.Read);

                pass.SetRenderAttachment(data.dst, 0, AccessFlags.Write);

                pass.SetRenderFunc((PassData d, RasterGraphContext ctx) =>
                {
                    d.mat.SetTexture("_ScreenTFM", tfm);
                    d.mat.SetTexture("_SST_BLURRED", sstBlurred);
                    BlitFullScreen(ctx.cmd, d.mat, d.passIndex, d.src);
                });
            }
        }

        private static void BlitFullScreen(RasterCommandBuffer cmd, Material mat, int pass, TextureHandle src)
        {
            if (src.IsValid())
                mat.SetTexture("_BlitTexture", src);
            Blitter.BlitTexture(cmd, src, new Vector4(1, 1, 0, 0), 0f, false);
            //Blitter.BlitTexture(context.cmd, data.inputTexture, new Vector4(1, 1, 0, 0), );

        }

        private class PassData
        {
            public Material mat;
            public TextureHandle src;
            public TextureHandle dst;
            public int passIndex;
        }
    }
}
