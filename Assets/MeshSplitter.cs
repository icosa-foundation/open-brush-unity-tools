using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using Unity.Burst;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;

public class MeshSplitter : MonoBehaviour
{
    [SerializeField] private float positionTolerance = 0.0001f;

    public MeshFilter meshFilter;

    [ContextMenu("Split Mesh")]
    public void DoSplitMesh()
    {
        if (meshFilter == null)
        {
            Debug.LogError("No MeshFilter found on GameObject");
            return;
        }
        var mesh = meshFilter.sharedMesh;
        if (mesh == null)
        {
            Debug.LogError("No mesh found on MeshFilter");
            return;
        }

        SplitMesh(mesh);
    }



    public GameObject[] SplitMesh(Mesh sourceMesh)
    {
        if (sourceMesh == null || sourceMesh.vertexCount == 0)
            return new GameObject[0];

        var vertices = sourceMesh.vertices;
        var triangles = sourceMesh.triangles;
        var normals = sourceMesh.normals;
        var uvs = sourceMesh.uv;

        // Create spatial hash of vertices
        var positionToIndices = new Dictionary<Vector3Int, List<int>>();
        var scaleFactor = Mathf.RoundToInt(1f / positionTolerance);

        for (int i = 0; i < vertices.Length; i++)
        {
            var hash = new Vector3Int(
                Mathf.RoundToInt(vertices[i].x * scaleFactor),
                Mathf.RoundToInt(vertices[i].y * scaleFactor),
                Mathf.RoundToInt(vertices[i].z * scaleFactor)
            );

            if (!positionToIndices.ContainsKey(hash))
                positionToIndices[hash] = new List<int>();
            positionToIndices[hash].Add(i);
        }

        // Create vertex mapping (original index -> position group index)
        var vertexGroups = new Dictionary<int, int>();
        var uniquePositions = new List<Vector3>();
        var originalToUnique = new Dictionary<int, int>();

        foreach (var group in positionToIndices.Values)
        {
            var representativeVertex = vertices[group[0]];
            var uniqueIndex = uniquePositions.Count;
            uniquePositions.Add(representativeVertex);

            foreach (var vertexIndex in group)
            {
                originalToUnique[vertexIndex] = uniqueIndex;
            }
        }

        // Create adjacency list for unique positions
        var adjacencyList = new List<HashSet<int>>();
        for (int i = 0; i < uniquePositions.Count; i++)
        {
            adjacencyList.Add(new HashSet<int>());
        }

        // Build connectivity using triangles
        for (int i = 0; i < triangles.Length; i += 3)
        {
            var v1 = originalToUnique[triangles[i]];
            var v2 = originalToUnique[triangles[i + 1]];
            var v3 = originalToUnique[triangles[i + 2]];

            adjacencyList[v1].Add(v2);
            adjacencyList[v1].Add(v3);
            adjacencyList[v2].Add(v1);
            adjacencyList[v2].Add(v3);
            adjacencyList[v3].Add(v1);
            adjacencyList[v3].Add(v2);
        }

        // Find connected components using BFS
        var visited = new bool[uniquePositions.Count];
        var components = new List<HashSet<int>>();

        for (int i = 0; i < uniquePositions.Count; i++)
        {
            if (visited[i]) continue;

            var component = new HashSet<int>();
            var queue = new Queue<int>();
            queue.Enqueue(i);
            visited[i] = true;

            while (queue.Count > 0)
            {
                var current = queue.Dequeue();
                component.Add(current);

                foreach (var neighbor in adjacencyList[current])
                {
                    if (!visited[neighbor])
                    {
                        queue.Enqueue(neighbor);
                        visited[neighbor] = true;
                    }
                }
            }

            components.Add(component);
        }

        // Create meshes for each component
        var result = new List<GameObject>();
        foreach (var component in components)
        {
            // Create reverse mapping from unique positions to original vertices
            var uniqueToOriginal = new Dictionary<int, List<int>>();
            foreach (var kvp in originalToUnique)
            {
                if (component.Contains(kvp.Value))
                {
                    if (!uniqueToOriginal.ContainsKey(kvp.Value))
                        uniqueToOriginal[kvp.Value] = new List<int>();
                    uniqueToOriginal[kvp.Value].Add(kvp.Key);
                }
            }

            // Collect all original vertices that belong to this component
            var componentVertices = new HashSet<int>();
            foreach (var uniqueIndex in component)
            {
                foreach (var originalIndex in uniqueToOriginal[uniqueIndex])
                {
                    componentVertices.Add(originalIndex);
                }
            }

            var go = CreateComponentGameObject(componentVertices, vertices, triangles, normals, uvs);
            if (go != null)
                result.Add(go);
        }

        return result.ToArray();
    }

    private GameObject CreateComponentGameObject(HashSet<int> componentVertices, Vector3[] sourceVertices,
        int[] sourceTriangles, Vector3[] sourceNormals, Vector2[] sourceUVs)
    {
        // Create vertex mapping (original index -> new index)
        var vertexMapping = new Dictionary<int, int>();
        var vertices = new List<Vector3>();
        var normals = new List<Vector3>();
        var uvs = new List<Vector2>();

        foreach (var oldIndex in componentVertices)
        {
            vertexMapping[oldIndex] = vertices.Count;
            vertices.Add(sourceVertices[oldIndex]);
            if (sourceNormals != null && sourceNormals.Length > oldIndex)
                normals.Add(sourceNormals[oldIndex]);
            if (sourceUVs != null && sourceUVs.Length > oldIndex)
                uvs.Add(sourceUVs[oldIndex]);
        }

        // Create triangles
        var triangles = new List<int>();
        for (int i = 0; i < sourceTriangles.Length; i += 3)
        {
            var v1 = sourceTriangles[i];
            var v2 = sourceTriangles[i + 1];
            var v3 = sourceTriangles[i + 2];

            if (componentVertices.Contains(v1) &&
                componentVertices.Contains(v2) &&
                componentVertices.Contains(v3))
            {
                triangles.Add(vertexMapping[v1]);
                triangles.Add(vertexMapping[v2]);
                triangles.Add(vertexMapping[v3]);
            }
        }

        if (triangles.Count == 0)
            return null;

        // Create mesh
        var mesh = new Mesh();
        mesh.SetVertices(vertices);
        mesh.SetTriangles(triangles.ToArray(), 0);
        if (normals.Count > 0)
            mesh.SetNormals(normals);
        if (uvs.Count > 0)
            mesh.SetUVs(0, uvs);
        mesh.RecalculateBounds();

        // Create game object
        var go = new GameObject("MeshPart");
        var mf = go.AddComponent<MeshFilter>();
        var mr = go.AddComponent<MeshRenderer>();
        mf.sharedMesh = mesh;

        return go;
    }
}
