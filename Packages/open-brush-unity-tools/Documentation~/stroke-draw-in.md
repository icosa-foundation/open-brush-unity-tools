# Stroke draw-in playback

`StrokeDrawInExample` replays an imported Open Brush sketch in its original drawing order. It is a
small runtime example that can be used directly or as a reference for a timeline or interaction
system.

## Requirements

- Export the sketch from Open Brush with `ExportStrokeTimestamp` enabled. The resulting GLB contains
  a `_TB_TIMESTAMP` VEC3 vertex attribute.
- Import the GLB with the Open Brush UnityGLTF import plugin enabled. It is enabled by default in
  this project.
- Keep the imported mesh CPU-readable. Enable **Read/Write Enabled** on an editor-imported GLB, or
  **Keep CPU Copy** when importing through UnityGLTF at runtime.
- Use brush materials whose shaders expose `_ClipStart` and `_ClipEnd`. Unsupported materials remain
  assigned but cannot be progressively revealed.

Read/Write is required because the example reads per-vertex times on the CPU when it builds its
playback targets. The importer does not serialize a second copy of every timestamp, avoiding an
additional four bytes per vertex in the imported asset and managed memory. A non-readable mesh is
skipped with a warning instead of stopping playback for the rest of the sketch.

## Import result

For each mesh containing valid timestamp data, the importer:

1. Reads `_TB_TIMESTAMP` from the glTF buffer.
2. Writes the VEC3 values to Unity UV channel 4 (API channel index `3`).
3. Adds `StrokeTimestampData` to the imported object.
4. Records the earliest and latest per-vertex times on that component.

Each timestamp vector contains the stroke start time, stroke end time, and per-vertex time in
seconds. Draw-in playback uses the third (`z`) value. The timestamp count must match the imported
mesh vertex count; unsupported, sparse, invalid, or truncated accessors are ignored with a warning.

## Setup

1. Select the imported GLB and enable **Read/Write Enabled** in its UnityGLTF import settings, then
   apply or reimport it.
2. Add `StrokeDrawInExample` to the imported sketch root, above the objects containing
   `StrokeTimestampData`.
3. Enter Play mode. Playback only builds and runs at runtime.
4. Configure the component in the Inspector:

   - **Play On Enable** starts playback whenever the component is enabled.
   - **Loop** returns to the first imported timestamp after reaching the last one.
   - **Playback Speed** scales elapsed time. `1` uses the exported timing and `0` stops time from
     advancing.
   - **Current Time** is the current exported timestamp in seconds. Changing it through the API
     immediately updates the visible geometry.

The timestamp range is taken across every valid descendant target, including inactive children.
At the end of non-looping playback, the component stops with the whole supported sketch visible.

## Runtime control

The component exposes simple playback methods:

```csharp
using OpenBrushUnityTools;
using UnityEngine;

public class DrawInControls : MonoBehaviour
{
    [SerializeField] private StrokeDrawInExample m_DrawIn;

    public void Play() => m_DrawIn.Play();
    public void Pause() => m_DrawIn.Pause();
    public void Restart() => m_DrawIn.Restart();

    public void Seek(float timestampSeconds)
    {
        m_DrawIn.CurrentTime = timestampSeconds;
    }
}
```

Call `RebuildTargets()` after changing the imported hierarchy, meshes, or renderer materials at
runtime. Rebuilding restarts target discovery but does not itself call `Play()`.

## Materials and renderer state

The helper does not modify the shared brush material assets. For each compatible source material,
it creates and reuses a runtime variant with `SHADER_SCRIPTING_ON` enabled, then assigns those
variants while playback is active. Materials without clipping properties are left unchanged.

Visibility is applied through each renderer's material property block using `_ClipStart` and
`_ClipEnd`. When the component is disabled or its targets are rebuilt, it restores both the exact
original material array and the complete original renderer property block. Runtime material
variants are then destroyed.

You do not need to use **Open Brush > Brush Materials > Shader Scripting > Enable All** for this
component; it enables shader scripting on its temporary variants automatically. The menu remains
useful for other systems that drive the clipping properties themselves.

## Playback limitations

- The example reveals mesh vertices in their imported order; it is not a stroke object animation
  or a general-purpose timeline.
- Exact playback requires per-vertex times to be monotonic in mesh vertex order. For non-monotonic
  data, the helper reveals only the contiguous prefix whose times have been reached, because the
  clipping shaders can represent only a vertex range.
- Meshes must remain CPU-readable for as long as targets may be rebuilt.
- A shader must support `SHADER_SCRIPTING_ON`, `_ClipStart`, and `_ClipEnd` for progressive reveal.
- UV channel 4 is reserved for `_TB_TIMESTAMP` on timestamped imported meshes.

## Troubleshooting

### Nothing plays

- Confirm the GLB was exported with `ExportStrokeTimestamp` enabled.
- Expand the imported hierarchy and confirm that its mesh objects have `StrokeTimestampData`.
- Confirm the Open Brush import plugin is enabled in the UnityGLTF settings, then reimport the GLB.
- Enter Play mode; `RebuildTargets()` intentionally does no work in Edit mode.

### A CPU-readable mesh warning appears

Enable **Read/Write Enabled** on the GLB importer and apply the setting. For a runtime UnityGLTF
import, enable **Keep CPU Copy** before loading the sketch.

### Some brushes appear immediately or do not draw in

Their materials may not expose the clipping properties used by the helper. Check that the assigned
shader supports `SHADER_SCRIPTING_ON`, `_ClipStart`, and `_ClipEnd`.

### Geometry appears in the wrong order

The imported vertex timestamps are probably not monotonic. The example can reveal only a contiguous
vertex prefix; use a timestamped export whose mesh vertices follow drawing order for exact playback.
