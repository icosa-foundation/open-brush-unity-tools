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
    public class ObImportPlugin : GLTFImportPlugin
    {
        public override string DisplayName => "Open Brush Importer";
        public override string Description => "Handles Open Brush specific import logic.";
        public override bool EnabledByDefault => true;

        public override GLTFImportPluginContext CreateInstance(GLTFImportContext context)
        {
            return new ObImportExtensionConfig();
        }

        public class ObImportExtensionConfig : GLTFImportPluginContext
        {

            private MaterialRemapping m_MaterialDictionary;
            private MaterialMultipassMapping m_MaterialMultipassMappings;

            public override void OnBeforeImport()
            {
                m_MaterialDictionary = Resources.Load<MaterialRemapping>("MaterialRemapping");
                m_MaterialMultipassMappings = Resources.Load<MaterialMultipassMapping>("MaterialMultipassMapping");
            }

            public override void OnAfterImportNode(Node node, int nodeIndex, GameObject nodeObject)
            {
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
                            Debug.Log($"Found {materials.Count} multipass materials for {existingMaterialName}");
                            mr.materials = materials.ToArray();
                        }
                        else
                        {
                            mr.sharedMaterial = mat;
                        }
                    }
                }
            }
        }
    }
}