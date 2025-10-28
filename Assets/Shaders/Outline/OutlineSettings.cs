using System;
using UnityEngine;

[Serializable]
public class OutlineSettings
{
    [Range(0, 100f)]
    public float scale = 1;
    public Color color = new Color(1, .5f, .5f, 1);

    [Range(0.00004f, 0.004f)]
    public float DepthThreshold;
    [Range(0.00004f, 1f)]
    public float NormalThreshold = 1f;

    public bool ONLY_NORMAL_ON = false;
}
