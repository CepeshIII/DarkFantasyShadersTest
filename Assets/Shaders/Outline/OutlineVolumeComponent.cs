using UnityEngine;
using UnityEngine.Rendering;

public sealed class OutlineVolumeComponent : VolumeComponent, IPostProcessComponent
{
    // Set the name of the volume component in the list in the Volume Profile.
    public OutlineVolumeComponent()
    {
        displayName = "OutlineEffect";
    }

    public ClampedFloatParameter scale = new ClampedFloatParameter(0f, 0f, 100f);
    public ColorParameter color = new ColorParameter( new Color(1, .5f, .5f, 1));

    public ClampedFloatParameter DepthThreshold = new ClampedFloatParameter(0.00004f, 0f, 1f);
    public ClampedFloatParameter NormalThreshold = new ClampedFloatParameter(0.00004f, 0.00004f, 1f);
    public EnumParameter<OutlineSource> outlineSource = new EnumParameter<OutlineSource>(OutlineSource.DepthOnly);



    public bool IsActive()
    {
        return scale.value > 0;
    }
}
