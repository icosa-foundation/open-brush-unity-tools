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
            return new OpenBrushImportPluginContext(context);
        }

        private class OpenBrushImportPluginContext : GLTFImportPluginContext
        {
            private const string TimestampAttribute = "_TB_TIMESTAMP";
            private readonly GLTFImportContext m_Context;
            private MaterialRemapping m_MaterialDictionary;
            private MaterialMultipassMapping m_MaterialMultipassMappings;

            // Imported meshes must not inherit the _IS_TILT_MESH state from the material used by
            // live Open Brush and .tilt geometry. Cache one copy for each exported mesh layout so
            // we don't dirty the shared project asset or create a copy per renderer.
            private readonly Dictionary<Material, Material> m_LegacyImportedVariants = new();
            private readonly Dictionary<Material, Material> m_BakedImportedVariants = new();

            public OpenBrushImportPluginContext(GLTFImportContext context)
            {
                m_Context = context;
            }

            public override void OnBeforeImport()
            {
                base.OnBeforeImport();
                m_MaterialDictionary = Resources.Load<MaterialRemapping>("MaterialRemapping");
                m_MaterialMultipassMappings = Resources.Load<MaterialMultipassMapping>("MaterialMultipassMapping");
            }

            public override void OnAfterImportNode(Node node, int nodeIndex, GameObject nodeObject)
            {
                base.OnAfterImportNode(node, nodeIndex, nodeObject);

                ImportStrokeTimestamps(node, nodeObject);

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
                    // Current BrushBaker exports use "ob-" material names and bake vertex shader
                    // effects into their meshes. The older "material_" and "brush_" formats use
                    // the legacy exported-mesh path instead.
                    bool isBakedExport = false;
                    if (existingMaterialName.StartsWith("ob-"))
                    {
                        // This is a current BrushBaker glTF from Open Brush.
                        string newMaterialName = existingMaterialName
                            .Replace("(Instance)", "")
                            .Replace(" ", "")
                            .Trim();
                        try
                        {
                            mat = m_MaterialDictionary.GetMaterialByName(newMaterialName);
                            isBakedExport = true;
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
                            var assigned = materials.Select(
                                material => GetImportedVariant(material, isBakedExport));
                            mr.sharedMaterials = assigned.ToArray();
                        }
                        else
                        {
                            mr.sharedMaterial = GetImportedVariant(mat, isBakedExport);
                        }
                    }
                }
            }

            private void ImportStrokeTimestamps(Node node, GameObject nodeObject)
            {
                if (node?.Mesh?.Value?.Primitives == null)
                {
                    return;
                }

                var timestampAccessors = new HashSet<int>();
                var timestamps = new List<Vector3>();
                foreach (var primitive in node.Mesh.Value.Primitives)
                {
                    if (primitive.Attributes == null ||
                        !primitive.Attributes.TryGetValue(TimestampAttribute, out AccessorId accessorId) ||
                        !timestampAccessors.Add(accessorId.Id))
                    {
                        continue;
                    }

                    Accessor accessor = accessorId.Value;
                    if (accessor.BufferView == null ||
                        accessor.Type != GLTFAccessorAttributeType.VEC3 ||
                        accessor.ComponentType != GLTFComponentType.Float ||
                        accessor.Sparse != null)
                    {
                        Debug.LogWarning($"Ignoring unsupported {TimestampAttribute} accessor on {nodeObject.name}");
                        return;
                    }

                    var bufferView = accessor.BufferView.Value;
                    byte[] data = m_Context.SceneImporter.GetBufferViewData(bufferView).ToArray();
                    int stride = bufferView.ByteStride > 0 ? (int)bufferView.ByteStride : sizeof(float) * 3;
                    if (accessor.Count == 0 || accessor.Count > int.MaxValue ||
                        accessor.ByteOffset > int.MaxValue || stride < sizeof(float) * 3)
                    {
                        Debug.LogWarning($"Ignoring invalid {TimestampAttribute} accessor on {nodeObject.name}");
                        return;
                    }

                    int count = (int)accessor.Count;
                    int offset = (int)accessor.ByteOffset;
                    long requiredBytes = (long)offset + (long)(count - 1) * stride + sizeof(float) * 3;
                    if (requiredBytes > data.Length)
                    {
                        Debug.LogWarning($"Ignoring truncated {TimestampAttribute} accessor on {nodeObject.name}");
                        return;
                    }

                    for (int i = 0; i < count; ++i)
                    {
                        int vertexOffset = offset + i * stride;
                        timestamps.Add(new Vector3(
                            BitConverter.ToSingle(data, vertexOffset),
                            BitConverter.ToSingle(data, vertexOffset + sizeof(float)),
                            BitConverter.ToSingle(data, vertexOffset + sizeof(float) * 2)));
                    }
                }

                if (timestamps.Count == 0)
                {
                    return;
                }

                Mesh mesh = nodeObject.GetComponent<MeshFilter>()?.sharedMesh;
                if (mesh == null)
                {
                    mesh = nodeObject.GetComponent<SkinnedMeshRenderer>()?.sharedMesh;
                }
                if (mesh == null || mesh.vertexCount != timestamps.Count)
                {
                    Debug.LogWarning(
                        $"Cannot import {TimestampAttribute} on {nodeObject.name}: " +
                        $"found {timestamps.Count} timestamps for {mesh?.vertexCount ?? 0} vertices");
                    return;
                }

                mesh.SetUVs(StrokeTimestampData.UvChannel, timestamps);
                var metadata = nodeObject.AddComponent<StrokeTimestampData>();
                metadata.Initialize(timestamps);
            }

            // Returns a material copy configured for an imported glTF mesh. Source materials use
            // _IS_TILT_MESH for live Open Brush and .tilt geometry, while _ISBAKEDEXPORT selects
            // between the two supported glTF layouts. Copies are registered as imported sub-assets
            // because UnityGLTF only persists materials from its own cache.
            private Material GetImportedVariant(Material src, bool isBakedExport)
            {
                if (src == null) return null;
                bool hasTiltMesh = src.HasProperty("_IS_TILT_MESH");
                bool hasBakedExport = src.HasProperty("_ISBAKEDEXPORT");
                if (!hasTiltMesh && !hasBakedExport) return src;

                var variants = isBakedExport
                    ? m_BakedImportedVariants
                    : m_LegacyImportedVariants;
                if (variants.TryGetValue(src, out var imported)) return imported;

                string layoutName = isBakedExport ? "Baked" : "Legacy";
                imported = new Material(src) { name = $"{src.name}-{layoutName}" };
                SetLocalBooleanKeyword(imported, "_IS_TILT_MESH", false);
                SetLocalBooleanKeyword(imported, "_ISBAKEDEXPORT", isBakedExport);
#if UNITY_EDITOR
                m_Context?.AssetContext?.AddObjectToAsset(imported.name, imported);
#endif
                variants[src] = imported;
                return imported;
            }

            private static void SetLocalBooleanKeyword(Material material, string name, bool enabled)
            {
                if (!material.HasProperty(name)) return;
                material.SetFloat(name, enabled ? 1f : 0f);
                material.SetKeyword(
                    new UnityEngine.Rendering.LocalKeyword(material.shader, name), enabled);
            }

            public override void OnAfterImportScene(GLTFScene scene, int sceneIndex, GameObject sceneObject)
            {
                base.OnAfterImportScene(scene, sceneIndex, sceneObject);
                var sketch = sceneObject.AddComponent<OpenBrushSketch>();
                var extras = scene?.Nodes?.FirstOrDefault()?.Root?.Extras;
                if (extras == null) return;

                sketch.TB_EnvironmentGuid = extras["TB_EnvironmentGuid"]?.Value<string>();
                sketch.TB_Environment = extras["TB_Environment"]?.Value<string>();
                sketch.TB_UseGradient = extras["TB_UseGradient"]?.Value<string>();
                sketch.TB_SkyColorA = extras["TB_SkyColorA"]?.Value<string>();
                sketch.TB_SkyColorB = extras["TB_SkyColorB"]?.Value<string>();
                sketch.TB_SkyGradientDirection = extras["TB_SkyGradientDirection"]?.Value<string>();
                sketch.TB_FogColor = extras["TB_FogColor"]?.Value<string>();
                sketch.TB_FogDensity = extras["TB_FogDensity"]?.Value<string>();
                sketch.TB_AmbientLightColor = extras["TB_AmbientLightColor"]?.Value<string>();
                sketch.TB_SceneLight0Color = extras["TB_SceneLight0Color"]?.Value<string>();
                sketch.TB_SceneLight0Rotation = extras["TB_SceneLight0Rotation"]?.Value<string>();
                sketch.TB_SceneLight1Color = extras["TB_SceneLight1Color"]?.Value<string>();
                sketch.TB_SceneLight1Rotation = extras["TB_SceneLight1Rotation"]?.Value<string>();
                sketch.TB_PoseTranslation = extras["TB_PoseTranslation"]?.Value<string>();
                sketch.TB_PoseRotation = extras["TB_PoseRotation"]?.Value<string>();
                sketch.TB_PoseScale = extras["TB_PoseScale"]?.Value<string>();
                sketch.TB_ExportedFromVersion = extras["TB_ExportedFromVersion"]?.Value<string>();
                sketch.TB_CameraTranslation = extras["TB_CameraTranslation"]?.Value<string>();
                sketch.TB_CameraRotation = extras["TB_CameraRotation"]?.Value<string>();
                sketch.TB_FlyMode = extras["TB_FlyMode"]?.Value<string>();
            }
        }
    }
}
