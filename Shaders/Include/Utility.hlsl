#ifndef CUSTOM_COLOR_UTILITIES_INCLUDED
#define CUSTOM_COLOR_UTILITIES_INCLUDED

#if COLORSPACE_YCBCR
    #define CS_RGB_YCbBr_MAT float3x3(0.299, 0.587, 0.114,  -0.168736, -0.331264, 0.5, 0.5, -0.418688, -0.081312)
    #define CS_YCbBr_RGB_MAT float3x3(1, 1.2e-6, 1.402,  1, -0.344136, -0.714136, 1, 1.772, 4.0e-7)
    #define CS_RGB_YCbBr_OFFSET float3(0, 0.5, 0.5)
#endif

#define DEFAULT_GAMMA 0.41666667

float3 ToDepthFormat(float3 In, float3 ColorSpaceDepth) {
    #if NO_GAMMA
        return trunc(In * ColorSpaceDepth);  
    #else
        return trunc(pow(In, DEFAULT_GAMMA) * ColorSpaceDepth);
    #endif
}

float3 FromDepthFormat(float3 In, float3 ColorSpaceDepth) {
    #if NO_GAMMA
        return saturate(In / ColorSpaceDepth);
    #else
        return pow(saturate(In / ColorSpaceDepth), 1 / DEFAULT_GAMMA);
    #endif
}


float3 ColorSpaceTransform(float3 In, float3 ColorSpaceDepth) {
    #if COLORSPACE_HSV
        float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
        float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
        float D = Q.x - min(Q.w, Q.y);
        float E = 1e-10;
        return float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);
    #elif COLORSPACE_YCBCR
            return mul(CS_RGB_YCbBr_MAT, In) + ceil(CS_RGB_YCbBr_OFFSET * ColorSpaceDepth);
    #elif COLORSPACE_LINEAR
        float3 linearRGBLo = In / 12.92;;
        float3 linearRGBHi = pow(max(abs((In + 0.055) / 1.055), 1.192092896e-07), float3(2.4, 2.4, 2.4));
        return float3(In <= 0.04045) ? linearRGBLo : linearRGBHi;
    #else
        return In;
    #endif
}

float3 InverseColorSpaceTransform(float3 In, float3 ColorSpaceDepth) {
    #if COLORSPACE_HSV
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 P = abs(frac(In.xxx + K.xyz) * 6.0 - K.www);
        return In.z * lerp(K.xxx, saturate(P - K.xxx), In.y);       
    #elif COLORSPACE_YCBCR

            return mul(CS_YCbBr_RGB_MAT, In - ceil(CS_RGB_YCbBr_OFFSET * ColorSpaceDepth));

    #elif COLORSPACE_LINEAR
        float3 sRGBLo = In * 12.92;
        float3 sRGBHi = (pow(max(abs(In), 1.192092896e-07), float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) * 1.055) - 0.055;
        return float3(In <= 0.0031308) ? sRGBLo : sRGBHi;
    #else
        return In;
    #endif
}


#ifdef BLUE_NOISE_DITHERING
float4 BlueNoiseDither(Texture2D blueNoiseTexture, SamplerState SS, float4 In, float4 Intensity, float4 ColorSpaceDepth, float2 UV, uint Seed, float2 ScreenSize) {
    float offset = GenerateHashedRandomFloat(Seed) * (ScreenSize.x * ScreenSize.y - 1);
        
    float2 coord = float2(fmod(UV.x * 1.05 * ScreenSize.x + offset, ScreenSize.x), 
                          fmod(UV.y * 1.05 * ScreenSize.y + trunc(offset / ScreenSize.x), ScreenSize.y));
    
    float4 noise = SAMPLE_TEXTURE2D(blueNoiseTexture, SS, coord/ScreenSize);
    
    
    #if IN_DEPTH_FORMAT
        //float4 t = step(0.5/ColorSpaceDepth, In) * step(In, ColorSpaceDepth - 0.5/ColorSpaceDepth);
        float4 rnd = noise - 0.5;
        float4 target_dither_amplitude = Intensity * ColorSpaceDepth;
        float4 max_dither_amplitude = max(1, min(In, ColorSpaceDepth - In));
        float4 dither_amplitude = min(target_dither_amplitude, max_dither_amplitude);
        return In + (rnd * dither_amplitude);
    #else
        //float4 t = step(0.5/ColorSpaceDepth, In) * step(In, 1 - 0.5/ColorSpaceDepth);
        float4 rnd = noise - 0.5;
        float4 target_dither_amplitude = Intensity;
        float4 max_dither_amplitude = max(1 / ColorSpaceDepth, min(In, 1 - In)) ;
        float4 dither_amplitude = min(target_dither_amplitude, max_dither_amplitude);
        return In + (rnd * dither_amplitude);
    #endif
    
}
#endif

#endif