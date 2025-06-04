using System;
using Newtonsoft.Json.Linq;
using UnityEditor;
#if UNITY_EDITOR
using UnityEditor.SceneManagement;
#endif
using UnityEngine;

[ExecuteInEditMode]
public class EnvironmentSetup : MonoBehaviour
{
#if UNITY_EDITOR
    public TextAsset m_EnvironmentJson;
    public string m_Guid;

    [ContextMenu("Apply Environment")]
    void ApplyEnvironment()
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

        var environments = JObject.Parse(m_EnvironmentJson.text);
        var environment = environments[m_Guid];
        var renderSettings = environment["renderSettings"];
        string skyboxName = renderSettings["skyboxCubemap"]?.Value<string>();
        if (String.IsNullOrEmpty(skyboxName))
        {
            skyboxName = "SkyboxGradient";
        }
        var skyboxPath = $"Packages/com.icosa.open-brush-unity-tools/Runtime/Environments/Materials/Skies/{skyboxName}.mat";
        var mat = (Material)AssetDatabase.LoadAssetAtPath(skyboxPath, typeof(Material));
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
            Cubemap tex;
            var reflectionPath = $"Packages/com.icosa.open-brush-unity-tools/Runtime/Environments/Textures/Reflection Maps/{reflectTexName}";
            tex = (Cubemap)AssetDatabase.LoadAssetAtPath($"{reflectionPath}.exr", typeof(Cubemap));
            if (tex == null)
            {
                tex = (Cubemap)AssetDatabase.LoadAssetAtPath($"{reflectionPath}.png", typeof(Cubemap));
                if (tex == null)
                {
                    tex = (Cubemap)AssetDatabase.LoadAssetAtPath($"{reflectionPath}.jpeg", typeof(Cubemap));
                }
            }
            if (tex != null)
            {
                tex.name = reflectTexName;
                RenderSettings.customReflection = tex;
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

        var camera = GetComponentInChildren<Camera>();
        camera.clearFlags = CameraClearFlags.Skybox;
        camera.backgroundColor = getColor(renderSettings["clearColor"]);

        var lights = GetComponentsInChildren<Light>();
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
        // "environmentReverbZone": "EnvironmentAudio/ReverbZone_Arena",

        EditorUtility.SetDirty(RenderSettings.skybox);
        EditorSceneManager.MarkSceneDirty(gameObject.scene);
    }
#endif
}
