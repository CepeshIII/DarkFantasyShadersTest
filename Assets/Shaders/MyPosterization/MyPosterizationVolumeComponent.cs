using System;
using UnityEngine.Rendering;

[Serializable]
[VolumeComponentMenu("Custom/MyPosterization")]
public class MyPosterizationVolumeComponent : VolumeComponent
{
    public BoolParameter withChanelAPosterization = new BoolParameter(true);
    public BoolParameter withChanelBPosterization = new BoolParameter(true);
    public BoolParameter withChanelCPosterization = new BoolParameter(true);
    public BoolParameter useColorPalette = new BoolParameter(false);

    public ClampedFloatParameter ChanelA  = new ClampedFloatParameter(0f, 0, 64);
    public ClampedFloatParameter ChanelB  = new ClampedFloatParameter(0f, 0, 64);
    public ClampedFloatParameter ChanelC  = new ClampedFloatParameter(0f, 0, 64);

    public ClampedFloatParameter MinChanelAValue = new ClampedFloatParameter(0f, 1, 0);
    public ClampedFloatParameter MinChanelBValue = new ClampedFloatParameter(0f, 1, 0);
    public ClampedFloatParameter MinChanelCValue = new ClampedFloatParameter(0f, 1, 0);
}
