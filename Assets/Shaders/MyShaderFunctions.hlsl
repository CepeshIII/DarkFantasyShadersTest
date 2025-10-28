void PixelizeDepth_float(
    float2 uv,
    Texture2D MainTex,
    SamplerState sampler_MainTex,
    Texture2D DepthTex,
    SamplerState sampler_DepthTex,
    float2 texelSize,
    out float4 color)
{
    float nearestDepth = 1.0;
    float4 nearestColor = 0;

    [unroll]
    for (int u = -2; u <= 2; u++)
    {
        [unroll]
        for (int v = -2; v <= 2; v++)
        {
            float2 offset = float2(u, v) * texelSize;
            float2 uvShifted = uv + offset;

            float rawDepth = DepthTex.Sample(sampler_DepthTex, uvShifted).r;
            float depth = Linear01Depth(rawDepth, _ZBufferParams);

            if (depth < nearestDepth)
            {
                nearestDepth = depth;
                nearestColor = MainTex.Sample(sampler_MainTex, uvShifted);
            }
        }
    }

    color = nearestColor;
}


float2 SquarePixelUvFactor(float2 textureSize)
{
    float minSize = min(textureSize.x, textureSize.y);
    float2 squareUVFactor = textureSize / minSize;
    return squareUVFactor;
}