Shader "Hidden/Custom/OKLCH_Posterization"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    // The Blit.hlsl file provides the vertex shader (Vert),
    // the input structure (Attributes), and the output structure (Varyings)
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Assets/Shaders/ColorPalette.hlsl"
    #include "Posterization.hlsl"


    #pragma multi_compile _ _USE_CHANEL_A_ON
    #pragma multi_compile _ _USE_CHANEL_B_ON
    #pragma multi_compile _ _USE_CHANEL_C_ON
    #pragma multi_compile _ _USE_COLOR_PALETTE_ON


// Converts from sRGB to OKLCH color space
float3 RGBToOKLCH(float3 linear_rgb)
{
    // convert linear rgb to xyz (CIE 1931 XYZ color space)
    float x = linear_rgb.r * 0.4124 + linear_rgb.g * 0.3576 + linear_rgb.b * 0.1805;
    float y = linear_rgb.r * 0.2126 + linear_rgb.g * 0.7152 + linear_rgb.b * 0.0722;
    float z = linear_rgb.r * 0.0193 + linear_rgb.g * 0.1192 + linear_rgb.b * 0.9505;

    // D65 white reference
    float xd65 = 0.95047;
    float yd65 = 1.0;
    float zd65 = 1.08883;

    // normalize
    float x_norm = x / xd65;
    float y_norm = y / yd65;
    float z_norm = z / zd65;

    // compute fx, fy, fz
    float fx = (x_norm > 0.008856) ? pow(x_norm, 1.0 / 3.0) : (7.787 * x_norm + 16.0 / 116.0);
    float fy = (y_norm > 0.008856) ? pow(y_norm, 1.0 / 3.0) : (7.787 * y_norm + 16.0 / 116.0);
    float fz = (z_norm > 0.008856) ? pow(z_norm, 1.0 / 3.0) : (7.787 * z_norm + 16.0 / 116.0);

    // convert from xyz to oklab
    float l_lab = 116.0 * fy - 16.0;
    float a_lab = 500.0 * (fx - fy);
    float b_lab = 200.0 * (fy - fz);

    // convert from oklab to oklch
    float c = sqrt(a_lab * a_lab + b_lab * b_lab);
    float h = degrees(atan2(b_lab, a_lab));
    if (h < 0.0) h += 360.0;

    return float3(l_lab / 100.0, c / 100.0, h / 360.0);
}

// Converts from OKLCH back to sRGB
float3 OKLCHToRGB(float3 lch)
{
    lch.z = lch.z * 360.0;

    // scale l and h
    float l = lch.x * 100.0;
    float c = lch.y * 100.0;
    float h_rad = radians(lch.z);

    // convert to oklab
    float a_lab = cos(h_rad) * c;
    float b_lab = sin(h_rad) * c;

    // compute f values
    float fy = (l + 16.0) / 116.0;
    float fx = a_lab / 500.0 + fy;
    float fz = fy - b_lab / 200.0;

    float3 f = float3(fx, fy, fz);
    float3 f_cubed = f * f * f;

    // condition for xyz
    float3 mask_xyz = step(float3(0.008856, 0.008856, 0.008856), f_cubed);
    float3 xyz = mask_xyz * f_cubed + (1.0 - mask_xyz) * ((f - float3(16.0/116.0, 16.0/116.0, 16.0/116.0)) / 7.787);

    // D65 white reference
    float3 d65 = float3(0.95047, 1.0, 1.08883);
    xyz *= d65;

    // convert from xyz to linear rgb
    float r = xyz.x *  3.2406 + xyz.y * -1.5372 + xyz.z * -0.4986;
    float g = xyz.x * -0.9689 + xyz.y *  1.8758 + xyz.z *  0.0415;
    float b = xyz.x *  0.0557 + xyz.y * -0.2040 + xyz.z *  1.0570;
    float3 linear_rgb = float3(r, g, b);

    return saturate(linear_rgb);
}


    float4 PosterizeColor(float4 color)
    {
        float3 OKLCH = RGBToOKLCH(color.rgb);
        float3 result = PosterizeChanels(OKLCH);
        return float4(OKLCHToRGB(result), 1);
    }


    half4 FragSharpen(Varyings i) : SV_Target
    {
        float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
        float3 posterizedColor = PosterizeColor(color);
        // return float4(posterizeColor, 1);

        #if _USE_COLOR_PALETTE_ON
            float3 nearestColor = GetNearestColor(posterizedColor, COLOR_PALETTE_3);
            return float4(nearestColor, 1);
        #endif

        return float4(posterizedColor, 1);
    }                                        
                                             
                                             
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 100
        ZWrite Off Cull Off

        Pass
        {
            Name "MyPosterizationPass"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragSharpen
            ENDHLSL
        }
    }
}
