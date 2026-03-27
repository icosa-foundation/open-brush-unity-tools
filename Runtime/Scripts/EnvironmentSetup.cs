using System;
using Newtonsoft.Json.Linq;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.SceneManagement;
#endif

namespace OpenBrushUnityTools
{
    public class EnvironmentSetup
{
    private static bool IsSet(string s) => !string.IsNullOrWhiteSpace(s);

    private static Color ParseColor(string s)
    {
        var parts = s.Split(',');
        return new Color(
            float.Parse(parts[0].Trim()),
            float.Parse(parts[1].Trim()),
            float.Parse(parts[2].Trim())
        );
    }

    private static Vector3 ParseVector3(string s)
    {
        var parts = s.Split(',');
        return new Vector3(
            float.Parse(parts[0].Trim()),
            float.Parse(parts[1].Trim()),
            float.Parse(parts[2].Trim())
        );
    }

    public static void ApplyEnvironment(OpenBrushSketch sketch, TextAsset environmentJson)
    {
        Color getColor(JToken jToken)
        {
            float r = jToken["r"].Value<float>();
            float g = jToken["g"].Value<float>();
            float b = jToken["b"].Value<float>();
            float a = jToken["a"].Value<float>();
            return new Color(r, g, b, a);
        }

        Vector3 getVector3(JToken jToken)
        {
            float x = jToken["x"].Value<float>();
            float y = jToken["y"].Value<float>();
            float z = jToken["z"].Value<float>();
            return new Vector3(x, y, z);
        }

        JObject environments = JObject.Parse(environmentJson.text);
        var environment = environments[sketch.TB_EnvironmentGuid];
        var renderSettings = environment["renderSettings"];

        // Skybox
        bool useGradient = IsSet(sketch.TB_UseGradient)
            ? sketch.TB_UseGradient.ToLower() == "true"
            : String.IsNullOrEmpty(renderSettings["skyboxCubemap"]?.Value<string>());
        string skyboxName = useGradient ? "SkyboxGradient" : renderSettings["skyboxCubemap"].Value<string>();
        var mat = Resources.Load<Material>($"Environments/Materials/Skies/{skyboxName}");
        mat.name = skyboxName;
        RenderSettings.skybox = mat;
        if (useGradient)
        {
            var colorA = IsSet(sketch.TB_SkyColorA) ? ParseColor(sketch.TB_SkyColorA) : getColor(environment["skyboxColorA"]);
            var colorB = IsSet(sketch.TB_SkyColorB) ? ParseColor(sketch.TB_SkyColorB) : getColor(environment["skyboxColorB"]);
            var gradientDir = IsSet(sketch.TB_SkyGradientDirection) ? ParseVector3(sketch.TB_SkyGradientDirection) : Vector3.up;
            RenderSettings.skybox.SetColor("_ColorA", colorA);
            RenderSettings.skybox.SetColor("_ColorB", colorB);
            RenderSettings.skybox.SetVector("_GradientDirection", gradientDir);
        }
        else
        {
            RenderSettings.skybox.SetFloat("_Exposure", renderSettings["skyboxExposure"].Value<float>());
            RenderSettings.skybox.SetColor("_Tint", getColor(renderSettings["skyboxTint"]));
        }

        var reflectTexName = renderSettings["reflectionCubemap"]?.Value<string>();
        if (reflectTexName != null)
        {
            var tex = Resources.Load<Cubemap>($"Environments/Textures/ReflectionMaps/{reflectTexName}");
            if (tex != null)
            {
                tex.name = reflectTexName;
                RenderSettings.customReflectionTexture = tex;
            }
            else
            {
                Debug.LogWarning($"Reflection cubemap not found: {reflectTexName}");
            }
        }

        RenderSettings.reflectionIntensity = renderSettings["reflectionIntensity"].Value<float>();
        RenderSettings.fog = renderSettings["fogEnabled"].Value<bool>();
        RenderSettings.fogMode = FogMode.Exponential;
        RenderSettings.fogColor = IsSet(sketch.TB_FogColor) ? ParseColor(sketch.TB_FogColor) : getColor(renderSettings["fogColor"]);
        RenderSettings.fogDensity = IsSet(sketch.TB_FogDensity) ? float.Parse(sketch.TB_FogDensity) : renderSettings["fogDensity"].Value<float>();
        RenderSettings.fogStartDistance = renderSettings["fogStartDistance"].Value<float>();
        RenderSettings.fogEndDistance = renderSettings["fogEndDistance"].Value<float>();
        RenderSettings.ambientSkyColor = IsSet(sketch.TB_AmbientLightColor) ? ParseColor(sketch.TB_AmbientLightColor) : getColor(renderSettings["ambientColor"]);

        var camera = sketch.gameObject.GetComponentInChildren<Camera>();
        camera.clearFlags = CameraClearFlags.Skybox;
        camera.backgroundColor = getColor(renderSettings["clearColor"]);

        var lights = sketch.gameObject.GetComponentsInChildren<Light>();
        var envLights = environment["lights"];
        for (var i = 0; i < lights.Length; i++)
        {
            var light = lights[i];
            var envLight = envLights[i];
            light.color = i == 0 && IsSet(sketch.TB_SceneLight0Color) ? ParseColor(sketch.TB_SceneLight0Color)
                        : i == 1 && IsSet(sketch.TB_SceneLight1Color) ? ParseColor(sketch.TB_SceneLight1Color)
                        : getColor(envLight["color"]);
            light.transform.position = getVector3(envLight["position"]);
            light.transform.rotation = i == 0 && IsSet(sketch.TB_SceneLight0Rotation) ? Quaternion.Euler(ParseVector3(sketch.TB_SceneLight0Rotation))
                                     : i == 1 && IsSet(sketch.TB_SceneLight1Rotation) ? Quaternion.Euler(ParseVector3(sketch.TB_SceneLight1Rotation))
                                     : Quaternion.Euler(getVector3(envLight["rotation"]));
            light.type = (LightType)Enum.Parse(typeof(LightType), envLight["type"].Value<string>());
            light.range = envLight["range"].Value<float>();
            light.spotAngle = envLight["spotAngle"].Value<float>();
            light.shadows = envLight["shadowsEnabled"].Value<bool>() ? LightShadows.Hard : LightShadows.None;
        }

        // TODO
        // "environmentReverbZone": "EnvironmentAudio/ReverbZone_Arena"

#if UNITY_EDITOR
        EditorUtility.SetDirty(RenderSettings.skybox);
        EditorSceneManager.MarkSceneDirty(sketch.gameObject.scene);
#endif
    }
}
}
