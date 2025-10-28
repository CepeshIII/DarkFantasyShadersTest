using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
public class MyPosterizationSettings
{
    public bool withChanelAPosterization = true;
    public bool withChanelBPosterization = true;
    public bool withChanelCPosterization = true;
    public bool useColorPalette = false;


    [Range(0, 128)] public float ChanelA = 0f;
    [Range(0, 128)] public float ChanelB = 0f;
    [Range(0, 128)] public float ChanelC = 0f;

    [Range(0, 1)] public float MinChanelAValue = 0f;
    [Range(0, 1)] public float MinChanelBValue = 0f;
    [Range(0, 1)] public float MinChanelCValue = 0f;
}
