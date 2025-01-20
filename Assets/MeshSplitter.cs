using Unity.Jobs;
using Unity.Collections;
using Unity.Mathematics;
using Unity.Burst;
using UnityEngine;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.Rendering;

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

        var meshDataArray = Mesh.AcquireReadOnlyMeshData(sourceMesh);
        var meshData = meshDataArray[0];

        var vertexCount = meshData.vertexCount;
        var indexCount = (int)sourceMesh.GetIndexCount(0);

        // Create native arrays
        var positions = new NativeArray<float3>(vertexCount, Allocator.TempJob);
        var indices = new NativeArray<int>(indexCount, Allocator.TempJob);
        var vertexGroups = new NativeArray<int>(vertexCount, Allocator.TempJob);
        var spatialHashMap = new NativeMultiHashMap<int3, int>(vertexCount, Allocator.TempJob);
        var vertexConnections = new NativeArray<int>(vertexCount, Allocator.TempJob);

        // Initialize vertex data
        var vertices = new NativeArray<Vector3>(vertexCount, Allocator.Temp);
        meshData.GetVertices(vertices);
        for (int i = 0; i < vertexCount; i++)
        {
            positions[i] = vertices[i];
            vertexGroups[i] = i;
            vertexConnections[i] = i;
        }
        vertices.Dispose();

        // Get indices
        meshData.GetIndices(indices, 0);

        // Step 1: Calculate spatial hashes in parallel
        var scaleFactor = (int)(1f / positionTolerance);
        var calculateHashesJob = new CalculateSpatialHashesJob
        {
            Positions = positions,
            ScaleFactor = scaleFactor,
            SpatialHashMap = spatialHashMap.AsParallelWriter()
        }.Schedule(vertexCount, 64);

        calculateHashesJob.Complete();

        // Step 2: Process spatial hash groups in parallel
        var processHashGroupsJob = new ProcessSpatialHashGroupsJob
        {
            SpatialHashMap = spatialHashMap,
            VertexGroups = vertexGroups
        }.Schedule();

        processHashGroupsJob.Complete();

        // Step 3: Process triangle connectivity in parallel batches
        var triangleCount = indexCount / 3;
        var processConnectivityJob = new ProcessConnectivityJob
        {
            Indices = indices,
            VertexGroups = vertexGroups,
            VertexConnections = vertexConnections
        }.Schedule(triangleCount, 64);

        processConnectivityJob.Complete();

        // Process results and create component sets
        var components = ProcessConnectedComponents(vertexGroups, vertexConnections, vertexCount);

        // Create game objects
        var result = new List<GameObject>();
        foreach (var component in components)
        {
            var go = CreateComponentGameObject(component, sourceMesh, meshData);
            if (go != null)
                result.Add(go);
        }

        // Cleanup
        positions.Dispose();
        indices.Dispose();
        vertexGroups.Dispose();
        spatialHashMap.Dispose();
        vertexConnections.Dispose();
        meshDataArray.Dispose();

        return result.ToArray();
    }

    [BurstCompile]
    private struct CalculateSpatialHashesJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<float3> Positions;
        public int ScaleFactor;
        public NativeMultiHashMap<int3, int>.ParallelWriter SpatialHashMap;

        public void Execute(int index)
        {
            var hash = GetSpatialHash(Positions[index]);
            SpatialHashMap.Add(hash, index);
        }

        private int3 GetSpatialHash(float3 position)
        {
            return new int3(
                (int)math.round(position.x * ScaleFactor),
                (int)math.round(position.y * ScaleFactor),
                (int)math.round(position.z * ScaleFactor)
            );
        }
    }

    [BurstCompile]
    private struct ProcessSpatialHashGroupsJob : IJob
    {
        [ReadOnly] public NativeMultiHashMap<int3, int> SpatialHashMap;
        public NativeArray<int> VertexGroups;

        public void Execute()
        {
            NativeArray<int3> keys = SpatialHashMap.GetKeyArray(Allocator.Temp);

            foreach (var key in keys)
            {
                var vertices = new NativeList<int>(Allocator.Temp);
                if (SpatialHashMap.TryGetFirstValue(key, out int firstVertex, out var iterator))
                {
                    vertices.Add(firstVertex);
                    while (SpatialHashMap.TryGetNextValue(out int nextVertex, ref iterator))
                    {
                        vertices.Add(nextVertex);
                    }

                    // Union all vertices in this spatial hash cell
                    for (int i = 1; i < vertices.Length; i++)
                    {
                        UnionVertices(vertices[0], vertices[i]);
                    }
                }
                vertices.Dispose();
            }
            keys.Dispose();
        }

        private int Find(int vertex)
        {
            while (VertexGroups[vertex] != vertex)
            {
                VertexGroups[vertex] = VertexGroups[VertexGroups[vertex]];
                vertex = VertexGroups[vertex];
            }
            return vertex;
        }

        private void UnionVertices(int v1, int v2)
        {
            int root1 = Find(v1);
            int root2 = Find(v2);

            if (root1 != root2)
            {
                if (root1 < root2)
                    VertexGroups[root2] = root1;
                else
                    VertexGroups[root1] = root2;
            }
        }
    }

    [BurstCompile]
    private struct ProcessConnectivityJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<int> Indices;
        [ReadOnly] public NativeArray<int> VertexGroups;
        [NativeDisableParallelForRestriction]
        public NativeArray<int> VertexConnections;

        public void Execute(int triangleIndex)
        {
            int baseIndex = triangleIndex * 3;
            var v1 = Indices[baseIndex];
            var v2 = Indices[baseIndex + 1];
            var v3 = Indices[baseIndex + 2];

            // Use position-based groups for connections
            UnionVertices(VertexGroups[v1], VertexGroups[v2]);
            UnionVertices(VertexGroups[v2], VertexGroups[v3]);
            UnionVertices(VertexGroups[v3], VertexGroups[v1]);
        }

        private int Find(int vertex)
        {
            while (VertexConnections[vertex] != vertex)
            {
                VertexConnections[vertex] = VertexConnections[VertexConnections[vertex]];
                vertex = VertexConnections[vertex];
            }
            return vertex;
        }

        private void UnionVertices(int v1, int v2)
        {
            int root1 = Find(v1);
            int root2 = Find(v2);

            if (root1 != root2)
            {
                if (root1 < root2)
                    VertexConnections[root2] = root1;
                else
                    VertexConnections[root1] = root2;
            }
        }
    }

    // Rest of the helper methods remain the same
    private List<HashSet<int>> ProcessConnectedComponents(NativeArray<int> vertexGroups,
        NativeArray<int> vertexConnections, int vertexCount)
    {
        var components = new Dictionary<int, HashSet<int>>();

        for (int i = 0; i < vertexCount; i++)
        {
            var root = FindRoot(i, vertexConnections);
            if (!components.TryGetValue(root, out var component))
            {
                component = new HashSet<int>();
                components[root] = component;
            }
            component.Add(i);
        }

        return components.Values.ToList();
    }

    private int FindRoot(int vertex, NativeArray<int> connections)
    {
        while (connections[vertex] != vertex)
        {
            connections[vertex] = connections[connections[vertex]];
            vertex = connections[vertex];
        }
        return vertex;
    }

    private GameObject CreateComponentGameObject(HashSet<int> verts, Mesh sourceMesh, Mesh.MeshData meshdata)
    {
        int vertexCount = sourceMesh.vertexCount;
        int indexCount = (int)sourceMesh.GetIndexCount(0);
        NativeArray<Vector3> sourceVertices = new NativeArray<Vector3>(vertexCount, Allocator.Temp);
        meshdata.GetVertices(sourceVertices);
        NativeArray<int> sourceTriangles = new NativeArray<int>(indexCount, Allocator.Temp);
        meshdata.GetIndices(sourceTriangles, 0);
        NativeArray<Vector3> sourceNormals = new NativeArray<Vector3>(indexCount, Allocator.Temp);
        meshdata.GetNormals(sourceNormals);
        NativeArray<Vector2> sourceUVs = new NativeArray<Vector2>(indexCount, Allocator.Temp);
        if (meshdata.HasVertexAttribute(VertexAttribute.TexCoord0))
        {
            meshdata.GetUVs(0, sourceUVs);
        }

        // Create vertex mapping (original index -> new index)
        var vertexMapping = new Dictionary<int, int>();
        var vertices = new List<Vector3>();
        var normals = new List<Vector3>();
        var uvs = new List<Vector2>();

        foreach (var oldIndex in verts)
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

            if (verts.Contains(v1) &&
                verts.Contains(v2) &&
                verts.Contains(v3))
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
