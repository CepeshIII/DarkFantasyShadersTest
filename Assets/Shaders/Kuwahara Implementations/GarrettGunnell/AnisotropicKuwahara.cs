
using UnityEngine;

namespace Rendering.AnisotropicKuwahara
{
    public enum KuwaharaNValues
    {
        One = 1,
        Four = 4,
        Six = 6,
        Eight = 8,
    }



    public enum KuwaharaTextureScale
    {
        [InspectorName("Full (100%)")] Full = 100,
        [InspectorName("Large (80%)")] Large = 80,
        [InspectorName("Medium (60%)")] Medium = 60,
        [InspectorName("Half (50%)")] Half = 50,
        [InspectorName("Quarter (25%)")] Quarter = 25
    }


    public static class KuwaharaTextureScaleExt
    {
        public static float ScaleFactor(this KuwaharaTextureScale s) => s switch
        {
            KuwaharaTextureScale.Full => 1.0f,
            KuwaharaTextureScale.Large => 0.8f,
            KuwaharaTextureScale.Medium => 0.6f,
            KuwaharaTextureScale.Half => 0.5f,
            KuwaharaTextureScale.Quarter => 0.25f,
            _ => 1.0f
        };
    }
}
