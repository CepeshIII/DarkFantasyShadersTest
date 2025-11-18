using System;
using UnityEngine;

[Serializable]
public class OutlineSettings
{
    [Range(0, 100f)]
    public float scale = 1;
    public Color color = new Color(1, .5f, .5f, 1);

    [Range(0.0f, 100f)]
    public float DepthThreshold;
    [Range(0.00004f, 100f)]
    public float NormalThreshold = 1f;

    [Range(0, 100)]
    public float DepthNormalThreshold;
    [Range(1, 300)]
    public float DepthNormalThresholdScale;

    public OutlineSource outlineSource = OutlineSource.DepthOnly;
}
