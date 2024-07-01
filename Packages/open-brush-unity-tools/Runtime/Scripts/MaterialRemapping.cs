using System;
using UnityEngine;
using System.Collections.Generic;

[System.Serializable]
public class MaterialEntry
{
    public string key;
    public Material material;
}

public class MaterialRemapping : ScriptableObject
{
    [SerializeField] private List<MaterialEntry> entries = new ();
    private Dictionary<string, Material> materialDictionary;
    public Dictionary<string, Material> MaterialDictionary => materialDictionary;

    public Material GetMaterial(string key)
    {
        if (materialDictionary == null)
        {
            InitializeDictionary();
        }
        return materialDictionary[key];
    }

    private void OnValidate()
    {
        InitializeDictionary();
    }

    private void InitializeDictionary()
    {
        Debug.Log("Initializing Material Dictionary");
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
