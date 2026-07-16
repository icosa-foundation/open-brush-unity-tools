using System.Collections.Generic;
using UnityEngine;

namespace OpenBrushUnityTools
{
    /// <summary>
    /// Identifies meshes whose Open Brush _TB_TIMESTAMP attribute was imported into UV4.
    /// Each Vector3 contains stroke start time, stroke end time, and per-vertex time in seconds.
    /// </summary>
    public class StrokeTimestampData : MonoBehaviour
    {
        public const int UvChannel = 3;

        [SerializeField] private float m_StartTime;
        [SerializeField] private float m_EndTime;

        public float StartTime => m_StartTime;
        public float EndTime => m_EndTime;

        public void Initialize(IReadOnlyList<Vector3> timestamps)
        {
            if (timestamps == null || timestamps.Count == 0)
            {
                m_StartTime = 0;
                m_EndTime = 0;
                return;
            }

            m_StartTime = timestamps[0].z;
            m_EndTime = timestamps[0].z;
            for (int i = 1; i < timestamps.Count; ++i)
            {
                m_StartTime = Mathf.Min(m_StartTime, timestamps[i].z);
                m_EndTime = Mathf.Max(m_EndTime, timestamps[i].z);
            }
        }
    }
}
