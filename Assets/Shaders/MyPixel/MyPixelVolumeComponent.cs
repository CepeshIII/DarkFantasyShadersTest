using UnityEngine.Rendering;

[System.Serializable, VolumeComponentMenu("Custom/MyPixelVolumeComponent")]
public class MyPixelVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter pixelSize = new ClampedFloatParameter(0f, 0f, 200f);
    public EnumParameter<SamplerFilterType> samplerFilterType = new EnumParameter<SamplerFilterType>(SamplerFilterType.LinearClamp);

    public bool IsActive()
    {
        return pixelSize.GetValue<float>() > 0.0f;
    }
}
