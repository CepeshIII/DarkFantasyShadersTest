using System;
using UnityEngine.Rendering;

[Serializable]
[VolumeComponentMenu("Custom/Sharpen")]
public class SharpenVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter intensity =
        new ClampedFloatParameter(0.05f, 0, 2f);
}
