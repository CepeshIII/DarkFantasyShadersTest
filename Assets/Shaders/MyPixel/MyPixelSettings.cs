using System;
using UnityEngine;


[Serializable]
public class MyPixelSettings
{
    [Range(0f, 200f)] public float pixelSize;
    public SamplerFilterType samplerFilterType;

}
