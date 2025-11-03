using System;
using UnityEngine;

[Serializable]
public class Kuwahara_TonynogoSettings
{
    [Range(0, 10)]
    public int radius = 0;

    [Range(0, 1f)]
    public float lerpValue = 0f;
}
