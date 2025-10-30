using System;
using UnityEngine;

[Serializable]
public class MyDitheringSettings
{
    [Range(0, 1f)]
    public float pixelate = 0f;
    [Range(0, 1f)]
    public float lerpValue = 0f;
    public BayerLevel bayerLevel = BayerLevel.Level4;
}
