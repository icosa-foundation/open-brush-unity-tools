// Enables the global SHADER_SCRIPTING_ON shader keyword while this component is active.
//
// The ported brush shaders gate their scripting / time-override path behind it (see
// TimeOverride.cginc): with it on, GetTime() returns
// lerp(_Time * _TimeSpeed, _TimeOverrideValue, _TimeBlend), so the material's exposed
// _TimeSpeed / _TimeBlend / _TimeOverrideValue properties become live and animation can be
// slowed or pinned. With it off, GetTime() is just _Time.
//
// Drop it on any GameObject and toggle the component. ExecuteAlways enables editor use.

using UnityEngine;

[ExecuteAlways]
[DisallowMultipleComponent]
[AddComponentMenu("Open Brush Unity Tools/Shader Scripting Flag")]
public class ShaderScriptingFlag : MonoBehaviour
{
    private const string kScriptingKeyword = "SHADER_SCRIPTING_ON";
    private static int s_ActiveCount;
    private static bool s_WasEnabled;

    private void OnEnable()
    {
        if (s_ActiveCount++ == 0)
        {
            s_WasEnabled = Shader.IsKeywordEnabled(kScriptingKeyword);
            Shader.EnableKeyword(kScriptingKeyword);
        }
    }

    private void OnDisable()
    {
        // Keep the keyword while another component needs it, and preserve the
        // state that existed before the first component was enabled.
        if (--s_ActiveCount == 0 && !s_WasEnabled)
        {
            Shader.DisableKeyword(kScriptingKeyword);
        }
    }
}
