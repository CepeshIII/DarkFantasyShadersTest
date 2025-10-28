using System;
using UnityEngine;


[Serializable]
public class MyPaletteSettings
{
    public Texture2D RampTexture;
    [Range(0f, 1f)] public float lerpValue;
}
