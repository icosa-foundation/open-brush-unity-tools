using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine.Serialization;

public class BatchMetadata : UnityEngine.MonoBehaviour
{
    [Serializable]
    public class SubsetMetadata
    {
        public uint m_HeadTimestampMs;
        public uint m_TailTimestampMs;
        public uint m_StartVertIndex;
        public uint m_VertLength;
        public uint m_Group;
    }

    public List<SubsetMetadata> m_Subsets;
}