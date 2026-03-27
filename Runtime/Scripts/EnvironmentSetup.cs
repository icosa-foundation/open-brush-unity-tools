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
        string skyboxName = renderSettings["skyboxCubemap"]?.Value<string>();
        if (String.IsNullOrEmpty(skyboxName))
        {
            skyboxName = "SkyboxGradient";
        }
        var mat = Resources.Load<Material>($"Environments/Materials/Skies/{skyboxName}");
        mat.name = skyboxName;
        RenderSettings.skybox = mat;
        if (skyboxName == "SkyboxGradient")
        {
            RenderSettings.skybox.SetColor("_ColorA", getColor(environment["skyboxColorA"]));
            RenderSettings.skybox.SetColor("_ColorB", getColor(environment["skyboxColorB"]));
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
        RenderSettings.fogColor = getColor(renderSettings["fogColor"]);
        RenderSettings.fogDensity = renderSettings["fogDensity"].Value<float>();
        RenderSettings.fogStartDistance = renderSettings["fogStartDistance"].Value<float>();
        RenderSettings.fogEndDistance = renderSettings["fogEndDistance"].Value<float>();
        RenderSettings.ambientSkyColor = getColor(renderSettings["ambientColor"]);

        var camera = sketch.gameObject.GetComponentInChildren<Camera>();
        camera.clearFlags = CameraClearFlags.Skybox;
        camera.backgroundColor = getColor(renderSettings["clearColor"]);

        var lights = sketch.gameObject.GetComponentsInChildren<Light>();
        var envLights = environment["lights"];
        for (var i = 0; i < lights.Length; i++)
        {
            var light = lights[i];
            var envLight = envLights[i];
            light.color = getColor(envLight["color"]);
            light.transform.position = getVector3(envLight["position"]);
            light.transform.rotation = Quaternion.Euler(getVector3(envLight["rotation"]));
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
