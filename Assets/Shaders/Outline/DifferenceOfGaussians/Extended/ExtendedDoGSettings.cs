using System;
using UnityEngine;

[Serializable]
public class ExtendedDoGSettings
{

    [Header("Edge Tangent Flow Settings")]
    public bool useFlow = true;

    [Range(0.0f, 5.0f)]
    public float structureTensorDeviation = 2.0f;

    [Range(0.0f, 20.0f)]
    public float lineIntegralDeviation = 2.0f;

    public Vector2 lineConvolutionStepSizes = new Vector2(1.0f, 1.0f);

    public bool calcDiffBeforeConvolution = true;

    [Header("Difference Of Gaussians Settings")]
    [Range(0.0f, 10.0f)]
    public float differenceOfGaussiansDeviation = 2.0f;

    [Range(0.1f, 5.0f)]
    public float stdevScale = 1.6f;

    [Range(0.0f, 100.0f)]
    public float Sharpness = 1.0f;

    public enum ThresholdMode
    {
        NoThreshold = 0,
        Tanh,
        Quantization,
        SmoothQuantization
    }

    [Header("Threshold Settings")]
    public ThresholdMode thresholdMode;

    [Range(1, 16)]
    public int quantizerStep = 2;

    [Range(0.0f, 100.0f)]
    public float whitePoint1 = 50.0f;

    [Range(0.0f, 10.0f)]
    public float softThreshold = 1.0f;

    public bool invert = false;

    [Header("Anti Aliasing Settings")]
    public bool smoothEdges = true;

    [Range(0.0f, 10.0f)]
    public float edgeSmoothDeviation = 1.0f;

    public Vector2 edgeSmoothStepSizes = new Vector2(1.0f, 1.0f);

    [Header("Cross Hatch Settings")]
    public bool enableHatching = false;
    public Texture hatchTexture = null;

    [Space(10)]

    [Range(0.0f, 8.0f)]
    public float hatchResolution1 = 1.0f;
    [Range(-180.0f, 180.0f)]
    public float hatchRotation1 = 90.0f;

    [Space(10)]
    public bool enableSecondLayer = true;
    [Range(0.0f, 100.0f)]
    public float whitePoint2 = 20.0f;
    [Range(0.0f, 8.0f)]
    public float hatchResolution2 = 1.0f;
    [Range(-180.0f, 180.0f)]
    public float hatchRotation2 = 60.0f;

    [Space(10)]
    public bool enableThirdLayer = true;
    [Range(0.0f, 100.0f)]
    public float whitePoint3 = 30.0f;
    [Range(0.0f, 8.0f)]
    public float hatchResolution3 = 1.0f;
    [Range(-180.0f, 180.0f)]
    public float hatchRotation3 = 120.0f;

    [Space(10)]
    public bool enableFourthLayer = true;
    [Range(0.0f, 100.0f)]
    public float whitePoint4 = 30.0f;
    [Range(0.0f, 8.0f)]
    public float hatchResolution4 = 1.0f;
    [Range(-180.0f, 180.0f)]
    public float hatchRotation4 = 120.0f;

    [Space(10)]
    public bool enableColoredPencil = false;
    [Range(-1.0f, 1.0f)]
    public float brightnessOffset = 0.0f;
    [Range(0.0f, 5.0f)]
    public float saturation = 1.0f;

    [Header("Blend Settings")]
    [Range(0.0f, 5.0f)]
    public float termStrength = 1.0f;

    public enum BlendMode
    {
        NoBlend = 0,
        Interpolate,
        TwoPointInterpolate
    }
    public BlendMode blendMode;

    public Color minColor = new Color(0.0f, 0.0f, 0.0f);
    public Color maxColor = new Color(1.0f, 1.0f, 1.0f);

    [Range(0.0f, 2.0f)]
    public float blendStrength = 1;
}
