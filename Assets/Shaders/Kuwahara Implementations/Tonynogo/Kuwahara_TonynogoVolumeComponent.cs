using UnityEngine;
using UnityEngine.Rendering;

public sealed class Kuwahara_TonynogoVolumeComponent : VolumeComponent, IPostProcessComponent
{
    // Set the name of the volume component in the list in the Volume Profile.
    public Kuwahara_TonynogoVolumeComponent()
    {
        displayName = "MyDitheringEffect";
    }

    public ClampedFloatParameter radius = new ClampedFloatParameter(0f, 0f, 10f);
    public ClampedFloatParameter lerpValue = new ClampedFloatParameter(0f, 0f, 1f);

    public bool IsActive()
    {
        return lerpValue.value > 0;
    }
}
