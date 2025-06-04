using UnityEngine;
using System.Collections.Generic;
using System.Linq;

[System.Serializable]
public class MultipassEntry
{
    public Material key;
    public Material[] materials;
}

public class MaterialMultipassMapping : ScriptableObject
{
    [SerializeField] private List<MultipassEntry> entries = new ();

    private Dictionary<Material, List<Material>> mappingDict;

    public List<Material> GetMultipassMaterials(Material material)
    {
        if (mappingDict == null)
        {
            mappingDict = new Dictionary<Material, List<Material>>();
            foreach (var entry in entries)
            {
                var mats = new List<Material> { entry.key };
                // Append entry.materials to mats
                    mats.AddRange(entry.materials);
                mappingDict[entry.key] = mats;
            }
        }
        return mappingDict.GetValueOrDefault(material);
    }
}
