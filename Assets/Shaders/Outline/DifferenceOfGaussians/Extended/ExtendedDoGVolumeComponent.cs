using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable, VolumeComponentMenu("Custom/ExtendedDoG")]
public sealed class ExtendedDoGVolumeComponent : VolumeComponent, IPostProcessComponent
{
    public BoolParameter useFlow = new BoolParameter(true);

    public ClampedFloatParameter structureTensorDeviation = new ClampedFloatParameter(2.0f, 0f, 5f);
    public ClampedFloatParameter differenceOfGaussiansDeviation = new ClampedFloatParameter(2.0f, 0f, 20f);
    public ClampedFloatParameter lineIntegralDeviation = new ClampedFloatParameter(2.0f, 0f, 20f);
    public ClampedFloatParameter edgeSmoothDeviation = new ClampedFloatParameter(1.0f, 0f, 10f);

    public Vector2Parameter convolutionSteps = new Vector2Parameter(new Vector2(1, 1));
    public Vector2Parameter smoothSteps = new Vector2Parameter(new Vector2(1, 1));

    public BoolParameter calcDiffBeforeConv = new BoolParameter(true);

    public ClampedFloatParameter stdevScale = new ClampedFloatParameter(1.6f, 0.1f, 5f);
    public ClampedFloatParameter whitePoint1 = new ClampedFloatParameter(50f, 0f, 100f);
    public ClampedFloatParameter whitePoint2 = new ClampedFloatParameter(20f, 0f, 100f);
    public ClampedFloatParameter whitePoint3 = new ClampedFloatParameter(30f, 0f, 100f);
    public ClampedFloatParameter whitePoint4 = new ClampedFloatParameter(30f, 0f, 100f);

    public ClampedFloatParameter Sharpness = new ClampedFloatParameter(1f, 0f, 100);
    public ClampedFloatParameter softThreshold = new ClampedFloatParameter(1f, 0f, 10);

    public ClampedIntParameter thresholdMode = new ClampedIntParameter(0, 0, 3);
    public ClampedIntParameter quantizerStep = new ClampedIntParameter(2, 1, 16);

    public BoolParameter invert = new BoolParameter(false);

    public BoolParameter smoothEdges = new BoolParameter(true);

    public BoolParameter enableHatching = new BoolParameter(false);
    public TextureParameter hatchTex = new TextureParameter(null);

    public ClampedFloatParameter hatchRes1 = new ClampedFloatParameter(1f, 0f, 8f);
    public ClampedFloatParameter hatchRot1 = new ClampedFloatParameter(90f, -180, 180);

    public BoolParameter enableLayer2 = new BoolParameter(true);
    public ClampedFloatParameter hatchRes2 = new ClampedFloatParameter(1f, 0f, 8f);
    public ClampedFloatParameter hatchRot2 = new ClampedFloatParameter(60f, -180, 180);

    public BoolParameter enableLayer3 = new BoolParameter(true);
    public ClampedFloatParameter hatchRes3 = new ClampedFloatParameter(1f, 0f, 8f);
    public ClampedFloatParameter hatchRot3 = new ClampedFloatParameter(120f, -180, 180);

    public BoolParameter enableLayer4 = new BoolParameter(true);
    public ClampedFloatParameter hatchRes4 = new ClampedFloatParameter(1f, 0f, 8f);
    public ClampedFloatParameter hatchRot4 = new ClampedFloatParameter(120f, -180, 180);

    public BoolParameter enableColoredPencil = new BoolParameter(false);
    public ClampedFloatParameter brightnessOffset = new ClampedFloatParameter(0f, -1, 1);
    public ClampedFloatParameter saturation = new ClampedFloatParameter(1f, 0f, 5f);

    public ColorParameter minColor = new ColorParameter(Color.black);
    public ColorParameter maxColor = new ColorParameter(Color.white);

    public ClampedFloatParameter blendStrength = new ClampedFloatParameter(1f, 0f, 2f);
    public ClampedFloatParameter dogStrength = new ClampedFloatParameter(1f, 0f, 5f);

    public ClampedIntParameter blendMode = new ClampedIntParameter(0, 0, 2);

    public bool IsActive() => true;
}
