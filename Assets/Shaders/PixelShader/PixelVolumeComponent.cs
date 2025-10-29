using UnityEngine;
using UnityEngine.Rendering;

public sealed class PixelVolumeComponent : VolumeComponent, IPostProcessComponent
{
    [Header("General Settings")]
    public ClampedFloatParameter radius = new ClampedFloatParameter(2f, 0f, 10f);
    public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 1f);

    [Header("Pixel Layer Sizes")]
    public FloatParameter layer1Size = new FloatParameter(100f);
    public FloatParameter layer2Size = new FloatParameter(150f);
    public FloatParameter layer3Size = new FloatParameter(250f);
    public FloatParameter layer4Size = new FloatParameter(500f);
    public FloatParameter layer5Size = new FloatParameter(1000f);

    [Header("Depth Thresholds")]
    public ClampedFloatParameter layerThreshold1 = new ClampedFloatParameter(0.00f, 0f, 1f);
    public ClampedFloatParameter layerThreshold2 = new ClampedFloatParameter(0.25f, 0f, 1f);
    public ClampedFloatParameter layerThreshold3 = new ClampedFloatParameter(0.50f, 0f, 1f);
    public ClampedFloatParameter layerThreshold4 = new ClampedFloatParameter(0.75f, 0f, 1f);
    public ClampedFloatParameter layerThreshold5 = new ClampedFloatParameter(1.00f, 0f, 1f);

    // Determines if this effect should be active at runtime
    public bool IsActive() => intensity.value > 0f;

    // Whether this effect requires depth texture
    public bool IsTileCompatible() => false;
}
