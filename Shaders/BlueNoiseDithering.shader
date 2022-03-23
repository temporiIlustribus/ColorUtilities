Shader "Hidden/Shader/BlueNoiseDithering"
{
    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch
    #pragma multi_compile __ COLORSPACE_HSV COLORSPACE_YCBCR COLORSPACE_LINEAR
    #pragma multi_compile __ NO_GAMMA 
    #pragma shader_feature IN_DEPTH_FORMAT

    #define BLUE_NOISE_DITHERING
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"
    #include "Assets/_MyAssets/Shaders/Include/Utility.hlsl"
    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    // List of properties to control your post process effect
    float _Intensity;
    float3 _ColorSpaceDepth;
    uint _Seed;
    TEXTURE2D_X(_InputTexture);
    TEXTURE2D(_BlueNoise);
    SamplerState BlueNoiseSample_trilinear_repeat;

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        uint2 positionSS = input.texcoord * _ScreenSize.xy;
        float csMax = max(max(_ColorSpaceDepth.x, _ColorSpaceDepth.y), _ColorSpaceDepth.z);
        #if IN_DEPTH_FORMAT
            float3 mainColor = ToDepthFormat(ColorSpaceTransform(LOAD_TEXTURE2D_X(_InputTexture, positionSS).xyz, _ColorSpaceDepth), _ColorSpaceDepth);
            float3 dithered = BlueNoiseDither(_BlueNoise, BlueNoiseSample_trilinear_repeat, float4(mainColor, csMax), _Intensity * float4(1, 1, 1, 1), float4(_ColorSpaceDepth, csMax), input.texcoord, _Seed, _ScreenSize).xyz;
            return float4(InverseColorSpaceTransform(FromDepthFormat(dithered, _ColorSpaceDepth), _ColorSpaceDepth), 0);
        #else
            float3 mainColor = ColorSpaceTransform(LOAD_TEXTURE2D_X(_InputTexture, positionSS).xyz, _ColorSpaceDepth);
            float3 dithered = BlueNoiseDither(_BlueNoise, BlueNoiseSample_trilinear_repeat, float4(mainColor, 0), _Intensity * float4(1, 1, 1, 1), float4(_ColorSpaceDepth, csMax), input.texcoord, _Seed, _ScreenSize).xyz;
            return float4(InverseColorSpaceTransform(dithered, _ColorSpaceDepth), 0);
        #endif
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "BlueNoiseDithering"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment CustomPostProcess
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}
