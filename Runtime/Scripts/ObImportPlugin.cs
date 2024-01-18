using UnityGLTF.Plugins;
using GLTF.Schema;
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
            public override void OnAfterImportNode(Node node, int nodeIndex, GameObject nodeObject)
            {
                var materialDictionary = Resources.Load<MaterialRemapping>("MaterialRemapping");
                var mr = nodeObject.GetComponent<MeshRenderer>();
                if (mr != null)
                {
                    var existingMaterialName = mr.sharedMaterial.name.Replace("(Instance)", "").Trim();
                    var mat = materialDictionary.GetMaterial(existingMaterialName);
                    if (mat != null)
                    {
                        mr.sharedMaterial = mat;
                    }
                    else
                    {
                        Debug.LogWarning($"Failed to find material {existingMaterialName} in MaterialRemapping");
                    }
                }
            }
        }
    }
}