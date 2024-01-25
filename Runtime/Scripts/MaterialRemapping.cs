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
        return materialDictionary[key];
    }

    [ContextMenu("Re-Initialize Dictionary")]
    private void InitializeDictionary()
    {
        materialDictionary = new Dictionary<string, Material>();
        foreach (MaterialEntry entry in entries)
        {
            string key = $"ob-{entry.key}";
            if (materialDictionary.ContainsKey(key))
            {
                Debug.LogError($"Duplicate key found in MaterialRemapping: {entry.key}");
            }
            else
            {
                materialDictionary.Add(key, entry.material);
            }
        }
    }
}
