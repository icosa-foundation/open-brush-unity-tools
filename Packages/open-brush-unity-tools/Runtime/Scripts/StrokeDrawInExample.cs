using System.Collections.Generic;
using UnityEngine;

namespace OpenBrushUnityTools
{
    /// <summary>
    /// Example playback helper for Open Brush _TB_TIMESTAMP data.
    /// Add this to an imported sketch root to replay its strokes using the brush shaders' clipping.
    /// </summary>
    [AddComponentMenu("Open Brush Unity Tools/Stroke Draw-In Example")]
    public class StrokeDrawInExample : MonoBehaviour
    {
        private static readonly int ClipStart = Shader.PropertyToID("_ClipStart");
        private static readonly int ClipEnd = Shader.PropertyToID("_ClipEnd");

        [SerializeField] private bool m_PlayOnEnable = true;
        [SerializeField] private bool m_Loop;
        [SerializeField, Min(0)] private float m_PlaybackSpeed = 1;
        [SerializeField] private float m_CurrentTime;

        private readonly List<Target> m_Targets = new();
        private readonly Dictionary<Material, Material> m_ShaderScriptingVariants = new();
        private readonly Dictionary<Renderer, Material[]> m_OriginalMaterials = new();
        private MaterialPropertyBlock m_PropertyBlock;
        private float m_FirstTimestamp;
        private float m_LastTimestamp;
        private bool m_Playing;

        private sealed class Target
        {
            public Renderer Renderer;
            public float[] Times;
            public bool IsMonotonic;
        }

        public float CurrentTime
        {
            get => m_CurrentTime;
            set
            {
                m_CurrentTime = value;
                Apply();
            }
        }

        private void OnEnable()
        {
            RebuildTargets();
            m_CurrentTime = m_FirstTimestamp;
            m_Playing = m_PlayOnEnable;
            Apply();
        }

        private void Update()
        {
            if (!m_Playing || m_Targets.Count == 0)
            {
                return;
            }

            m_CurrentTime += Time.deltaTime * m_PlaybackSpeed;
            if (m_CurrentTime > m_LastTimestamp)
            {
                if (m_Loop)
                {
                    m_CurrentTime = m_FirstTimestamp;
                }
                else
                {
                    m_CurrentTime = m_LastTimestamp;
                    m_Playing = false;
                }
            }
            Apply();
        }

        private void OnDisable()
        {
            RestoreMaterials();
        }

        public void RebuildTargets()
        {
            RestoreMaterials();
            m_Targets.Clear();
            if (!Application.isPlaying)
            {
                return;
            }

            m_PropertyBlock ??= new MaterialPropertyBlock();
            m_FirstTimestamp = float.PositiveInfinity;
            m_LastTimestamp = float.NegativeInfinity;

            foreach (StrokeTimestampData timestampData in
                     GetComponentsInChildren<StrokeTimestampData>(includeInactive: true))
            {
                var renderer = timestampData.GetComponent<Renderer>();
                Mesh mesh = timestampData.GetComponent<MeshFilter>()?.sharedMesh;
                if (mesh == null)
                {
                    mesh = timestampData.GetComponent<SkinnedMeshRenderer>()?.sharedMesh;
                }
                if (renderer == null || mesh == null)
                {
                    continue;
                }

                var imported = new List<Vector3>();
                mesh.GetUVs(StrokeTimestampData.UvChannel, imported);
                if (imported.Count != mesh.vertexCount)
                {
                    continue;
                }

                if (!EnableShaderScripting(renderer))
                {
                    continue;
                }

                var times = new float[imported.Count];
                bool monotonic = true;
                for (int i = 0; i < imported.Count; ++i)
                {
                    times[i] = imported[i].z;
                    if (i > 0 && times[i] < times[i - 1])
                    {
                        monotonic = false;
                    }
                    m_FirstTimestamp = Mathf.Min(m_FirstTimestamp, times[i]);
                    m_LastTimestamp = Mathf.Max(m_LastTimestamp, times[i]);
                }

                m_Targets.Add(new Target
                {
                    Renderer = renderer,
                    Times = times,
                    IsMonotonic = monotonic,
                });
            }

            if (m_Targets.Count == 0)
            {
                m_FirstTimestamp = 0;
                m_LastTimestamp = 0;
            }
        }

        private bool EnableShaderScripting(Renderer renderer)
        {
            Material[] sourceMaterials = renderer.sharedMaterials;
            var playbackMaterials = new Material[sourceMaterials.Length];
            bool supportsClipping = false;
            for (int i = 0; i < sourceMaterials.Length; ++i)
            {
                Material source = sourceMaterials[i];
                if (source == null || !source.HasProperty(ClipStart) || !source.HasProperty(ClipEnd))
                {
                    playbackMaterials[i] = source;
                    continue;
                }

                supportsClipping = true;
                if (!m_ShaderScriptingVariants.TryGetValue(source, out Material variant))
                {
                    variant = new Material(source) { name = $"{source.name}-DrawIn" };
                    if (variant.HasProperty("SHADER_SCRIPTING"))
                    {
                        variant.SetFloat("SHADER_SCRIPTING", 1);
                    }
                    variant.EnableKeyword("SHADER_SCRIPTING_ON");
                    m_ShaderScriptingVariants.Add(source, variant);
                }
                playbackMaterials[i] = variant;
            }

            if (supportsClipping)
            {
                m_OriginalMaterials[renderer] = sourceMaterials;
                renderer.sharedMaterials = playbackMaterials;
            }
            return supportsClipping;
        }

        private void RestoreMaterials()
        {
            if (m_PropertyBlock != null)
            {
                foreach (Target target in m_Targets)
                {
                    if (target.Renderer == null)
                    {
                        continue;
                    }
                    target.Renderer.GetPropertyBlock(m_PropertyBlock);
                    m_PropertyBlock.SetFloat(ClipStart, -1);
                    m_PropertyBlock.SetFloat(ClipEnd, -1);
                    target.Renderer.SetPropertyBlock(m_PropertyBlock);
                }
            }

            foreach (var pair in m_OriginalMaterials)
            {
                if (pair.Key != null)
                {
                    pair.Key.sharedMaterials = pair.Value;
                }
            }
            m_OriginalMaterials.Clear();

            foreach (Material material in m_ShaderScriptingVariants.Values)
            {
                if (material != null)
                {
                    if (Application.isPlaying)
                    {
                        Destroy(material);
                    }
                    else
                    {
                        DestroyImmediate(material);
                    }
                }
            }
            m_ShaderScriptingVariants.Clear();
        }

        public void Play()
        {
            m_Playing = true;
        }

        public void Pause()
        {
            m_Playing = false;
        }

        public void Restart()
        {
            m_CurrentTime = m_FirstTimestamp;
            m_Playing = true;
            Apply();
        }

        private void Apply()
        {
            if (m_PropertyBlock == null)
            {
                return;
            }

            foreach (Target target in m_Targets)
            {
                int visibleVertices = target.IsMonotonic
                    ? UpperBound(target.Times, m_CurrentTime)
                    : VisiblePrefix(target.Times, m_CurrentTime);

                target.Renderer.GetPropertyBlock(m_PropertyBlock);
                if (visibleVertices == 0)
                {
                    m_PropertyBlock.SetFloat(ClipStart, 0);
                    m_PropertyBlock.SetFloat(ClipEnd, .5f);
                }
                else if (visibleVertices >= target.Times.Length)
                {
                    m_PropertyBlock.SetFloat(ClipStart, -1);
                    m_PropertyBlock.SetFloat(ClipEnd, -1);
                }
                else
                {
                    m_PropertyBlock.SetFloat(ClipStart, -1);
                    m_PropertyBlock.SetFloat(ClipEnd, visibleVertices);
                }
                target.Renderer.SetPropertyBlock(m_PropertyBlock);
            }
        }

        private static int UpperBound(float[] values, float value)
        {
            int low = 0;
            int high = values.Length;
            while (low < high)
            {
                int middle = low + (high - low) / 2;
                if (values[middle] <= value)
                {
                    low = middle + 1;
                }
                else
                {
                    high = middle;
                }
            }
            return low;
        }

        private static int VisiblePrefix(float[] values, float value)
        {
            int visible = 0;
            while (visible < values.Length && values[visible] <= value)
            {
                ++visible;
            }
            return visible;
        }
    }
}
