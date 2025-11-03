using System;
using UnityEngine;

[Serializable]
public class Kuwahara_Daniel_IlettSettings
{
    [Range(1f, 10f)]
    public float kernelSize = 1f;

    [Range(0, 1f)]
    public float lerpValue = 0f;
}
