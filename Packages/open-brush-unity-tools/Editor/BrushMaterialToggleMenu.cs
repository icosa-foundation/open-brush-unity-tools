using UnityEditor;
using UnityEngine;
using System.IO;

public static class BrushMaterialToggleMenu
{
    const string ShaderMaterialRoot = "Packages/com.icosa.open-brush-unity-tools/Runtime/Shaders";
    const string AudioReactiveProperty = "AUDIO_REACTIVE";
    const string AudioReactiveKeyword = "AUDIO_REACTIVE";
    const string ShaderScriptingProperty = "SHADER_SCRIPTING";
    const string ShaderScriptingKeyword = "SHADER_SCRIPTING_ON";

    [MenuItem("Open Brush/Brush Materials/Audio Reactivity/Enable All")]
    static void EnableAllAudioReactivity()
    {
        SetAll(AudioReactiveProperty, AudioReactiveKeyword, true, "audio reactivity");
    }

    [MenuItem("Open Brush/Brush Materials/Audio Reactivity/Disable All")]
    static void DisableAllAudioReactivity()
    {
        SetAll(AudioReactiveProperty, AudioReactiveKeyword, false, "audio reactivity");
    }

    [MenuItem("Open Brush/Brush Materials/Shader Scripting/Enable All")]
    static void EnableAllShaderScripting()
    {
        SetAll(ShaderScriptingProperty, ShaderScriptingKeyword, true, "shader scripting");
    }

    [MenuItem("Open Brush/Brush Materials/Shader Scripting/Disable All")]
    static void DisableAllShaderScripting()
    {
        SetAll(ShaderScriptingProperty, ShaderScriptingKeyword, false, "shader scripting");
    }

    static void SetAll(string propertyName, string keywordName, bool enabled, string label)
    {
        int changed = 0;
        int skipped = 0;
        string[] materialGuids = AssetDatabase.FindAssets("t:Material", new[] { ShaderMaterialRoot });

        AssetDatabase.StartAssetEditing();
        try
        {
            foreach (string guid in materialGuids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (material == null)
                {
                    skipped++;
                    continue;
                }

                bool hasProperty = material.HasProperty(propertyName);
                bool hasKeyword = HasKeyword(material, keywordName);
                bool supportsKeyword = hasKeyword || ShaderAssetContainsKeyword(material.shader, keywordName);
                if (!hasProperty && !supportsKeyword)
                {
                    skipped++;
                    continue;
                }

                Undo.RecordObject(material, $"Set {label}");

                bool changedMaterial = false;
                if (hasProperty && !Mathf.Approximately(material.GetFloat(propertyName), enabled ? 1f : 0f))
                {
                    material.SetFloat(propertyName, enabled ? 1f : 0f);
                    changedMaterial = true;
                }

                if (supportsKeyword && hasKeyword != enabled)
                {
                    if (enabled)
                    {
                        material.EnableKeyword(keywordName);
                    }
                    else
                    {
                        material.DisableKeyword(keywordName);
                    }
                    changedMaterial = true;
                }

                if (changedMaterial)
                {
                    EditorUtility.SetDirty(material);
                    changed++;
                }
            }
        }
        finally
        {
            AssetDatabase.StopAssetEditing();
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"Set {label} {(enabled ? "on" : "off")} for {changed} brush material(s); skipped {skipped} material(s) without {propertyName}/{keywordName} support.");
    }

    static bool HasKeyword(Material material, string keywordName)
    {
        foreach (string keyword in material.shaderKeywords)
        {
            if (keyword == keywordName)
            {
                return true;
            }
        }
        return false;
    }

    static bool ShaderAssetContainsKeyword(Shader shader, string keywordName)
    {
        if (shader == null)
        {
            return false;
        }

        string shaderPath = AssetDatabase.GetAssetPath(shader);
        if (string.IsNullOrEmpty(shaderPath) || !File.Exists(shaderPath))
        {
            return false;
        }

        return File.ReadAllText(shaderPath).Contains(keywordName);
    }
}
