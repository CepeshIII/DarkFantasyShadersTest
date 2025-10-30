using System;
using UnityEngine;

[Serializable]
public class Kuwahara_TonynogoSettings
{
    [Range(0f, 10f)]
    public float radius = 0f;

    [Range(0, 1f)]
    public float lerpValue = 0f;
}
