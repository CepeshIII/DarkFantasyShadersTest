using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
public class DifferenceOfGaussiansSettings
{
    public Color color = new Color(1, .5f, .5f, 1);

    [Range(0, 10)]
    public int gaussianKernelSize = 1;
    
    [Range(0, 1)]
    public int thresholding;
    [Range(0, 1)]
    public int invert;
    [Range(0, 1)]
    public int tanh;

    [Range(0.1f, 5.0f)]
    public float Sigma = 1f;
    [Range(-1.0f, 1.0f)]
    public float Threshold = 1f;
    [Range(0.1f, 5.0f)]
    public float K = 1f;

    [Range(0.01f, 5.0f)]
    public float Tau = 1f;
    [Range(0.01f, 100.0f)]
    public float Phi = 1f;

}
