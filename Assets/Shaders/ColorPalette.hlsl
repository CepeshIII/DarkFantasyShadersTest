// ColorPalette.hlsl

    // Example palette.gdshaderinc ↓
static const float3 COLOR_PALETTE[11] =
{
    float3(0.137, 0.137, 0.137), // #232323
	float3(0.227, 0.227, 0.227), // #393939
	float3(0.318, 0.318, 0.318), // #515151
	float3(0.409, 0.409, 0.409), // #696969
 	float3(0.500, 0.500, 0.500), // #808080
	float3(0.591, 0.591, 0.591), // #999999
	float3(0.682, 0.682, 0.682), // #B0B0B0
	float3(0.773, 0.773, 0.773), // #C4C4C4
	float3(0.864, 0.864, 0.864), // #D8D8D8
	float3(0.955, 0.955, 0.955), // #F2F2F2
	float3(1.000, 1.000, 1.000) // #FFFFFF
};

static const float3 COLOR_PALETTE_2[11] =
{
    float3(0.619, 0.004, 0.259), // #9e0142
    float3(0.835, 0.243, 0.310), // #d53e4f
    float3(0.957, 0.427, 0.263), // #f46d43
    float3(0.992, 0.682, 0.380), // #fdae61
    float3(0.996, 0.878, 0.545), // #fee08b
    float3(1.000, 1.000, 0.749), // #ffffbf
    float3(0.902, 0.961, 0.596), // #e6f598
    float3(0.671, 0.863, 0.643), // #abdda4
    float3(0.400, 0.761, 0.647), // #66c2a5
    float3(0.200, 0.529, 0.741), // #3288bd
    float3(0.369, 0.310, 0.635) // #5e4fa2
};


static const float3 COLOR_PALETTE_3[40] =
{
    float3(0.941, 0.929, 1.000), // #f0edff
    float3(0.639, 0.592, 0.847), // #a397d8
    float3(0.196, 0.153, 0.388), // #322763
    float3(0.078, 0.008, 0.157), // #140228
    float3(0.976, 0.902, 0.761), // #f9e6c2
    float3(0.976, 0.525, 0.361), // #f9865c
    float3(0.827, 0.047, 0.114), // #d30c1d
    float3(0.510, 0.000, 0.227), // #82003a
    float3(1.000, 0.922, 0.729), // #ffebba
    float3(0.976, 0.667, 0.282), // #f9aa48
    float3(0.616, 0.208, 0.118), // #9e351e
    float3(0.353, 0.043, 0.157), // #5b0b28
    float3(1.000, 0.976, 0.749), // #fff9bf
    float3(0.808, 0.764, 0.224), // #cec239
    float3(0.553, 0.553, 0.106), // #8e8e1b
    float3(0.180, 0.329, 0.000), // #2e5400
    float3(0.914, 1.000, 0.576), // #e9ff93
    float3(0.667, 0.776, 0.224), // #aac639
    float3(0.220, 0.600, 0.000), // #389900
    float3(0.000, 0.286, 0.075), // #004913
    float3(0.816, 0.976, 0.518), // #d0f984
    float3(0.431, 0.878, 0.271), // #6ee045
    float3(0.114, 0.776, 0.169), // #1dc62b
    float3(0.020, 0.447, 0.220), // #057238
    float3(0.898, 1.000, 0.820), // #e5ffd1
    float3(0.624, 1.000, 0.624), // #9eff9e
    float3(0.196, 0.859, 0.506), // #32db81
    float3(0.027, 0.478, 0.478), // #077a7a
    float3(0.729, 1.000, 0.827), // #baffd3
    float3(0.439, 1.000, 0.894), // #70ffe4
    float3(0.137, 0.710, 0.937), // #23b5ef
    float3(0.020, 0.141, 0.467), // #052477
    float3(0.902, 0.788, 1.000), // #e6c9ff
    float3(0.714, 0.388, 0.976), // #b663f9
    float3(0.384, 0.184, 0.929), // #622fed
    float3(0.129, 0.047, 0.357), // #210c5b
    float3(0.976, 0.780, 0.922), // #f9c7eb
    float3(0.749, 0.541, 0.918), // #bf8aea
    float3(0.337, 0.259, 0.686), // #5642af
    float3(0.149, 0.098, 0.388) // #271963
};


float3 GetNearestColor(float3 color, float3 colorPallete[40])
{
    float minDiff = 1.0;
    float3 nearestColor = color;

    // Loop through the palette
    [unroll]
    for (int i = 0; i < 40; i++)
    {
        float currDist = distance(colorPallete[i], color);
        if (currDist < minDiff)
        {
            minDiff = currDist;
            nearestColor = colorPallete[i];
        }
    }

    return nearestColor;
}


float3 GetNearestColor(float3 color, Texture2D paletteTex, SamplerState sampler_palette, int paletteSize)
{
    float minDiff = 999999.0;
    float3 nearestColor = color;

    // Loop through palette texture
    for (int i = 0; i < paletteSize; i++)
    {
        // Sample palette horizontally along U axis
        float2 uv = float2((i + 0.5) / paletteSize, 0.5);
        float3 paletteColor = paletteTex.Sample(sampler_palette, uv).rgb;

        // Compute Euclidean distance in RGB space
        float currDist = distance(paletteColor, color);
        if (currDist < minDiff)
        {
            minDiff = currDist;
            nearestColor = paletteColor;
        }
    }

    return nearestColor;
}


