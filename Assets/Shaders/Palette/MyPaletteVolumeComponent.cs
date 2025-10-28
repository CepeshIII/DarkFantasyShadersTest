using UnityEngine.Rendering;

[System.Serializable, VolumeComponentMenu("Custom/MyPaletteVolumeComponent")]
public class MyPaletteVolumeComponent : VolumeComponent
{
    public Texture2DParameter rampAtlas = new Texture2DParameter(null);
    public ClampedFloatParameter lerpValue = new ClampedFloatParameter(0f, 0f, 1f);


    public bool IsActive()
    {
        return rampAtlas.value != null && lerpValue.GetValue<float>() > 0.0f;
    }
}
