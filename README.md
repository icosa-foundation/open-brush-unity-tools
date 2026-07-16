## Open Brush Unity Tools
# Installation

Install by downloading the whole repository and opening it as a Unity Project

To add it to an existing project.

Using the Package Manager: "Add package from git URL" first add UnityGLTF: https://github.com/KhronosGroup/UnityGLTF.git (unless your project already contains it)
Then add this package: https://github.com/icosa-foundation/open-brush-unity-tools.git#upm

# Stroke draw-in example

Open Brush GLB files exported with `ExportStrokeTimestamp` enabled contain a per-vertex
`_TB_TIMESTAMP` attribute. The importer stores this VEC3 data in Unity UV channel 4 and adds a
`StrokeTimestampData` component to each imported object that contains it.

Add `StrokeDrawInExample` to the imported sketch root to replay the sketch. The component uses the
imported per-vertex times to drive the existing `_ClipStart`/`_ClipEnd` support in the brush shaders.
It creates shared runtime material variants with `SHADER_SCRIPTING_ON` enabled and restores the
original materials when disabled.

The helper is intentionally a small example rather than a timeline system. Timestamp data must be
monotonic in mesh vertex order for exact playback; if it is not, the helper reveals the largest
chronological vertex prefix that the clipping shaders can represent.
