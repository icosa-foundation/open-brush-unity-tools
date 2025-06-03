using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public static class RemoveStrokeMetadata
{
    [MenuItem("Open Brush/Remove StrokeMetadata components from Scene")]
    static void RemoveAllStrokeMetadata()
    {
        int count = 0;

        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            var scene = SceneManager.GetSceneAt(i);
            foreach (var rootObj in scene.GetRootGameObjects())
            {
                var metadataComponents = rootObj.GetComponentsInChildren<StrokeMetadata>(true);
                foreach (var comp in metadataComponents)
                {
                    Undo.DestroyObjectImmediate(comp);
                    count++;
                }
            }
        }

        Debug.Log($"Removed {count} StrokeMetadata components.");
        EditorSceneManager.MarkAllScenesDirty();
    }
}