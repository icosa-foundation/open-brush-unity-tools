using UnityEngine;
using System.Collections.Generic;

[System.Serializable]
public class MaterialEntry
{
    public string key;
    public Material material;
}

[CreateAssetMenu(fileName = "MaterialRemapping", menuName = "ScriptableObjects/MaterialRemapping", order = 1)]
public class MaterialRemapping : ScriptableObject
{
    [SerializeField] private List<MaterialEntry> entries = new ();
    private Dictionary<string, Material> materialDictionary;

    public Material GetMaterial(string key)
    {
        if (materialDictionary == null)
        {
            InitializeDictionary();
        }
        if (materialDictionary.TryGetValue(key, out Material material))
        {
            return material;
        }
        return null;
    }

    private void InitializeDictionary()
    {
        materialDictionary = new Dictionary<string, Material>();
        foreach (MaterialEntry entry in entries)
        {
            if (!materialDictionary.ContainsKey(entry.key))
            {
                materialDictionary.Add(entry.key, entry.material);
            }
        }
    }
}
