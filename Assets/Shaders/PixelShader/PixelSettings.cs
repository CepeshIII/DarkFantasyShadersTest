using System;
using UnityEngine;


[Serializable]
public class PixelSettings
{
    [Header("General Settings")]
    [Range(0f, 10f)] public float radius = 2f;
    [Range(0f, 1f)] public float intensity = 1f;

    [Header("Pixel Layer Sizes")]
    public float layer1Size = 100f;
    public float layer2Size = 150f;
    public float layer3Size = 250f;
    public float layer4Size = 500f;
    public float layer5Size = 1000f;

    [Header("Depth Thresholds (0–1 Linear Depth)")]
    [Range(0f, 1f)] public float layerThreshold1 = 0.00f;
    [Range(0f, 1f)] public float layerThreshold2 = 0.25f;
    [Range(0f, 1f)] public float layerThreshold3 = 0.50f;
    [Range(0f, 1f)] public float layerThreshold4 = 0.75f;
    [Range(0f, 1f)] public float layerThreshold5 = 1.00f;
}
