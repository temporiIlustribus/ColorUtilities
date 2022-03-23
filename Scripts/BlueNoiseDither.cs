using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using static UnityEngine.Rendering.VolumeParameter;
using System;

public enum ColorSpace {
    RGB,
    HSV,
    YCbCr,
    LINEAR
}

public enum ColorSpaceGamma {
    DEFAULT,
    NONE,
}

[Serializable]
public sealed class ColorSpaceParameter : VolumeParameter<ColorSpace> {
    public ColorSpaceParameter(ColorSpace value, bool overrideState = false) : base(value, overrideState) { }
}

[Serializable]
public sealed class ColorSpaceGammaParameter : VolumeParameter<ColorSpaceGamma> {
    public ColorSpaceGammaParameter(ColorSpaceGamma value, bool overrideState = false) : base(value, overrideState) { }
}


[Serializable, VolumeComponentMenu("Post-processing/TVision/Dither")]
public sealed class BlueNoiseDither : CustomPostProcessVolumeComponent, IPostProcessComponent 
{
    public Material _material;
    public Shader _shader;

    public bool IsActive() => _material != null && 
                               intensity.value > Mathf.Epsilon &&
                               blueNoise.value != null;

    // Do not forget to add this post process in the Custom Post Process Orders list (Project Settings > HDRP Default Settings).
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    const string kShaderName = "Hidden/Shader/BlueNoiseDithering";
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0, 0, 1);
    public ColorSpaceParameter ditherColorSpace = new ColorSpaceParameter(ColorSpace.RGB);
    public ColorSpaceGammaParameter ditherGamma = new ColorSpaceGammaParameter(ColorSpaceGamma.DEFAULT);
    public BoolParameter useDepthFormat = new BoolParameter(true);
    public UnityEngine.Rendering.Vector3Parameter colorSpaceDepth = new UnityEngine.Rendering.Vector3Parameter(new Vector3(255, 255, 255));
    public UnityEngine.Rendering.TextureParameter blueNoise = new UnityEngine.Rendering.TextureParameter(null);

    int blockSeed;

    static class ShaderPropertyIDs
    {
        internal static readonly int Seed = Shader.PropertyToID("_Seed");
        internal static readonly int Intensity = Shader.PropertyToID("_Intensity");
        internal static readonly int ColorSpaceDepth = Shader.PropertyToID("_ColorSpaceDepth");
        internal static readonly int InputTexture = Shader.PropertyToID("_InputTexture");
        internal static readonly int BlueNoise = Shader.PropertyToID("_BlueNoise");
    }

    public override void Setup()
    {
        if (Shader.Find(kShaderName) != null){
            if (_shader != null)
                _material = CoreUtils.CreateEngineMaterial(_shader);
            else
                _material = CoreUtils.CreateEngineMaterial(kShaderName);
        }

        if (ditherColorSpace.value == ColorSpace.HSV) {
            _material.EnableKeyword("COLORSPACE_HSV");
            _material.DisableKeyword("COLORSPACE_YCBCR");
            _material.DisableKeyword("COLORSPACE_LINEAR");
        } else if (ditherColorSpace.value == ColorSpace.YCbCr) {
            _material.EnableKeyword("COLORSPACE_YCBCR");
            _material.DisableKeyword("COLORSPACE_HSV");
            _material.DisableKeyword("COLORSPACE_LINEAR");
        } else if (ditherColorSpace.value == ColorSpace.LINEAR) {
            _material.EnableKeyword("COLORSPACE_LINEAR");
            _material.DisableKeyword("COLORSPACE_HSV");
            _material.DisableKeyword("COLORSPACE_YCBCR");
        } else {
            _material.DisableKeyword("COLORSPACE_HSV");
            _material.DisableKeyword("COLORSPACE_YCBCR");
            _material.DisableKeyword("COLORSPACE_LINEAR");
        }

        if (useDepthFormat.value) {
            _material.EnableKeyword("IN_DEPTH_FORMAT");
        } else {
            _material.DisableKeyword("IN_DEPTH_FORMAT");
        }

        if (ditherGamma.value == ColorSpaceGamma.NONE) {
            _material.EnableKeyword("NO_GAMMA");
        }  else {
            _material.DisableKeyword("NO_GAMMA");
        }
    
        _material.SetTexture(ShaderPropertyIDs.BlueNoise, blueNoise.value);
    }


    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        // Require material to do stuff...
        if (_material == null) 
        {
            if (_shader != null)
                _material = CoreUtils.CreateEngineMaterial(_shader);
            Debug.Log("WTF");
            return;  
        }
        float curTime = Time.time;
        _material.SetInt(ShaderPropertyIDs.Seed, (((int)(curTime * 10000) * 75) + 73) % 0x10001);  // Use LCG for seeds!
        _material.SetFloat(ShaderPropertyIDs.Intensity, intensity.value);
        _material.SetVector(ShaderPropertyIDs.ColorSpaceDepth, colorSpaceDepth.value);
        _material.SetTexture(ShaderPropertyIDs.InputTexture, source);

        HDUtils.DrawFullScreen(cmd, _material, destination, null, 0);
    }

    public override void Cleanup()
    {
        CoreUtils.Destroy(_material);
    }

}