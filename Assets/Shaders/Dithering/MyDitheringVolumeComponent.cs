using UnityEngine;
using UnityEngine.Rendering;


public enum BayerLevel
{
    Level2, 
    Level4, 
    Level8
}


public sealed class MyDitheringVolumeComponent : VolumeComponent, IPostProcessComponent
{
    // Set the name of the volume component in the list in the Volume Profile.
    public MyDitheringVolumeComponent()
    {
        displayName = "MyDitheringEffect";
    }

    public ClampedFloatParameter pixelate = new ClampedFloatParameter(0f, 0, 1f);
    public ClampedFloatParameter lerpValue = new ClampedFloatParameter(0f, 0f, 1f);
    public EnumParameter<BayerLevel> bayerLevel = new EnumParameter<BayerLevel>(BayerLevel.Level4);

    public bool IsActive()
    {
        return lerpValue.value > 0;
    }
}
