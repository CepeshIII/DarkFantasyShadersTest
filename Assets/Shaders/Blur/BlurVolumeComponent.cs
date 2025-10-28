using UnityEngine.Rendering;
using System;

[Serializable]
[VolumeComponentMenu("Custom/Blur")]
public class BlurVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter horizontalBlur =
        new ClampedFloatParameter(0.05f, 0, 0.5f);
    public ClampedFloatParameter verticalBlur =
        new ClampedFloatParameter(0.05f, 0, 0.5f);
}
