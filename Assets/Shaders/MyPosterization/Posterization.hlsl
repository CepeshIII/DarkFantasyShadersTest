float _ChanelA;
float _ChanelB;
float _ChanelC;

float _MinChanelAValue;
float _MinChanelBValue;
float _MinChanelCValue;


float Posterize(float value, float levels)
{
    return floor(value * levels) / levels;
}


float3 PosterizeChanels(float3 chanels)
{
    float a = chanels.x;
    float b = chanels.y;
    float c = chanels.z;

#if _USE_CHANEL_A_ON
        a = lerp(_MinChanelAValue, 1.0, a);
        a = Posterize(a, _ChanelA);
#endif

#if _USE_CHANEL_B_ON
        b = lerp(_MinChanelBValue, 1.0, b);
        b = Posterize(b, _ChanelB);
#endif

#if _USE_CHANEL_C_ON
        c = lerp(_MinChanelCValue, 1.0, c);
        c = Posterize(c, _ChanelC);
#endif

    return float3(a, b, c);
}