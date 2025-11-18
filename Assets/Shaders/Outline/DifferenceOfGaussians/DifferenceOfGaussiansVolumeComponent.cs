using UnityEngine;
using UnityEngine.Rendering;

public sealed class DifferenceOfGaussiansVolumeComponent : VolumeComponent, IPostProcessComponent
{
    // Set the name of the volume component in the list in the Volume Profile.
    public DifferenceOfGaussiansVolumeComponent()
    {
        displayName = "OutlineEffect";
    }

    public ColorParameter color = new ColorParameter( new Color(1, .5f, .5f, 1));

    public ClampedIntParameter gaussianKernelSize = new ClampedIntParameter(5, 1, 10);
    public ClampedIntParameter thresholding = new ClampedIntParameter(0, 0, 1);
    public ClampedIntParameter invert = new ClampedIntParameter(0, 0, 1);
    public ClampedIntParameter tanh = new ClampedIntParameter(0, 0, 1);

    public ClampedFloatParameter Sigma = new ClampedFloatParameter(1f, 0f, 10f);
    public ClampedFloatParameter Threshold = new ClampedFloatParameter(1f, 0f, 30f);
    public ClampedFloatParameter K = new ClampedFloatParameter(1f, 0f, 30f);
    public ClampedFloatParameter Tau = new ClampedFloatParameter(1f, 0f, 30f);
    public ClampedFloatParameter Phi = new ClampedFloatParameter(1f, 0f, 30f);


    public bool IsActive()
    {
        return true;
    }
}
