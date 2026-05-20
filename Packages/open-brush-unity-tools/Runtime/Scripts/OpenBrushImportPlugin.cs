using System;
using System.Collections.Generic;
using System.Linq;
using GLTF.Extensions;
using UnityGLTF.Plugins;
using GLTF.Schema;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace OpenBrushUnityTools
{
    public class OpenBrushImportPlugin : GLTFImportPlugin
    {
        public override string DisplayName => "Open Brush Importer";
        public override string Description => "Handles Open Brush specific import logic.";
        public override bool EnabledByDefault => true;

        public override GLTFImportPluginContext CreateInstance(GLTFImportContext context)
        {
            return new OpenBrushImportPluginContext();
        }

        private class OpenBrushImportPluginContext : GLTFImportPluginContext
        {
            private MaterialRemapping m_MaterialDictionary;
            private MaterialMultipassMapping m_MaterialMultipassMappings;

            public override void OnBeforeImport()
            {
                base.OnBeforeImport();
                m_MaterialDictionary = Resources.Load<MaterialRemapping>("MaterialRemapping");
                m_MaterialMultipassMappings = Resources.Load<MaterialMultipassMapping>("MaterialMultipassMapping");
            }

            public override void OnAfterImportNode(Node node, int nodeIndex, GameObject nodeObject)
            {
                base.OnAfterImportNode(node, nodeIndex, nodeObject);

                var strokeJson = node?.Mesh?.Value?.Extras?["ICOSA_strokeInfo"];
                if (strokeJson != null)
                {
                    var reader = strokeJson.CreateReader();
                    var strokeInfo = reader.ReadAsDictionary(() => reader.ReadAsString());
                    var metadata = nodeObject.AddComponent<StrokeMetadata>();
                    UInt32.TryParse(strokeInfo["HeadTimestampMs"], out metadata.m_HeadTimestampMs);
                    UInt32.TryParse(strokeInfo["TailTimestampMs"], out metadata.m_TailTimestampMs);
                }
                else
                {
                    // Is there ever more than one primitive that could contain metadata?
                    var batchJson = node?.Mesh?.Value?.Primitives[0].Extras?["ICOSA_batchInfo"];
                    if (batchJson != null)
                    {
                        var metadata = nodeObject.AddComponent<BatchMetadata>();
                        metadata.m_Subsets = new List<BatchMetadata.SubsetMetadata>();
                        foreach (var metadataItem in batchJson)
                        {
                            var subsetMetadata = new BatchMetadata.SubsetMetadata();
                            UInt32.TryParse(metadataItem["HeadTimestampMs"].Value<string>(), out subsetMetadata.m_HeadTimestampMs);
                            UInt32.TryParse(metadataItem["TailTimestampMs"].Value<string>(), out subsetMetadata.m_TailTimestampMs);
                            UInt32.TryParse(metadataItem["StartVertIndex"].Value<string>(), out subsetMetadata.m_StartVertIndex);
                            UInt32.TryParse(metadataItem["VertLength"].Value<string>(), out subsetMetadata.m_VertLength);
                            UInt32.TryParse(metadataItem["Group"].Value<string>(), out subsetMetadata.m_Group);
                            metadata.m_Subsets.Add(subsetMetadata);
                        }
                    }
                }

                var mr = nodeObject.GetComponent<MeshRenderer>();
                if (mr != null)
                {
                    string existingMaterialName = mr.sharedMaterial.name;
                    Material mat = null;
                    if (existingMaterialName.StartsWith("ob-"))
                    {
                        // This is a older legacy glb from Open Brush
                        string newMaterialName = existingMaterialName
                            .Replace("(Instance)", "")
                            .Replace(" ", "")
                            .Trim();
                        try
                        {
                            mat = m_MaterialDictionary.GetMaterialByName(newMaterialName);
                            // Modern OpenBrush bakes vertex shaders effects into the mesh when exporting
                            if (mat != null && mat.HasProperty("_ISBAKEDEXPORT"))
                            {
                                // The inspector checkbox is bound to the float property, while the
                                // shader branch keys off the keyword of the same name (the ShaderGraph
                                // Boolean keyword's reference). Set both so they stay in sync.
                                mat.SetFloat("_ISBAKEDEXPORT", 1f);
                                var bakedKeyword = new UnityEngine.Rendering.LocalKeyword(mat.shader, "_ISBAKEDEXPORT");
                                mat.SetKeyword(bakedKeyword, true);
                            }

                        }
                        catch (KeyNotFoundException)
                        {
                            Debug.LogWarning($"Material Remapping: No match for {existingMaterialName} on {nodeObject.name}");
                        }
                    }
                    else if (existingMaterialName.StartsWith("material_"))
                    {
                        // This is a new glb from Open Brush
                        string guid = existingMaterialName
                            .Replace("material_", "")
                            .Trim();

                        // If the remaining string starts with a material name
                        // eg "SoftHighlighter-accb32f5-4509-454f-93f8-1df3fd31df1b"
                        // then remove the name portion
                        int firstDashIndex = guid.IndexOf('-');
                        if (firstDashIndex > 0 && Guid.TryParse(guid.Substring(firstDashIndex + 1), out _))
                        {
                            guid = guid.Substring(firstDashIndex + 1);
                        }

                        try
                        {
                            mat = m_MaterialDictionary.GetMaterialByGuid(guid);
                        }
                        catch (KeyNotFoundException)
                        {
                            Debug.LogWarning($"Material Remapping: No match for {guid} on {nodeObject.name}");
                        }
                    }
                    else if (existingMaterialName.StartsWith("brush_"))
                    {
                        // This is a recent legacy glb from Open Brush
                        string newMaterialName = existingMaterialName[6..] // Remove "brush_"
                            .Replace(" ", "")
                            .Trim();
                        try
                        {
                            mat = m_MaterialDictionary.GetMaterialByName($"ob-{newMaterialName}");
                        }
                        catch (KeyNotFoundException)
                        {
                            Debug.LogWarning($"Material Remapping: No match for {existingMaterialName} on {nodeObject.name}");
                        }
                    }



                    if (mat == null)
                    {
                        Debug.LogWarning($"MaterialRemapping: No material for {existingMaterialName} on {nodeObject.name}");
                    }
                    else
                    {
                        var materials = m_MaterialMultipassMappings.GetMultipassMaterials(mat);
                        if (materials?.Count > 0)
                        {
                            mr.materials = materials.ToArray();
                        }
                        else
                        {
                            mr.sharedMaterial = mat;
                        }
                    }
                }
            }

            public override void OnAfterImportScene(GLTFScene scene, int sceneIndex, GameObject sceneObject)
            {
                base.OnAfterImportScene(scene, sceneIndex, sceneObject);
                var sketch = sceneObject.AddComponent<OpenBrushSketch>();
                sketch.TB_EnvironmentGuid = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_EnvironmentGuid"]?.Value<string>();
                sketch.TB_Environment = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_Environment"]?.Value<string>();
                sketch.TB_UseGradient = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_UseGradient"]?.Value<string>();
                sketch.TB_SkyColorA = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SkyColorA"]?.Value<string>();
                sketch.TB_SkyColorB = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SkyColorB"]?.Value<string>();
                sketch.TB_SkyGradientDirection = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SkyGradientDirection"]?.Value<string>();
                sketch.TB_FogColor = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_FogColor"]?.Value<string>();
                sketch.TB_FogDensity = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_FogDensity"]?.Value<string>();
                sketch.TB_AmbientLightColor = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_AmbientLightColor"]?.Value<string>();
                sketch.TB_SceneLight0Color = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SceneLight0Color"]?.Value<string>();
                sketch.TB_SceneLight0Rotation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SceneLight0Rotation"]?.Value<string>();
                sketch.TB_SceneLight1Color = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SceneLight1Color"]?.Value<string>();
                sketch.TB_SceneLight1Rotation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_SceneLight1Rotation"]?.Value<string>();
                sketch.TB_PoseTranslation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_PoseTranslation"]?.Value<string>();
                sketch.TB_PoseRotation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_PoseRotation"]?.Value<string>();
                sketch.TB_PoseScale = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_PoseScale"]?.Value<string>();
                sketch.TB_ExportedFromVersion = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_ExportedFromVersion"]?.Value<string>();
                sketch.TB_CameraTranslation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_CameraTranslation"]?.Value<string>();
                sketch.TB_CameraRotation = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_CameraRotation"]?.Value<string>();
                sketch.TB_FlyMode = scene.Nodes.FirstOrDefault()?.Root?.Extras["TB_FlyMode"]?.Value<string>();
            }
        }
    }
}