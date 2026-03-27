using JetBrains.Annotations;
using UnityEngine;

namespace OpenBrushUnityTools
{
    public class OpenBrushSketch : MonoBehaviour
    {
        public string TB_EnvironmentGuid;
        public string TB_Environment;
        public string TB_UseGradient;
        public string TB_SkyColorA;
        public string TB_SkyColorB;
        public string TB_SkyGradientDirection;
        public string TB_FogColor;
        public string TB_FogDensity;
        public string TB_AmbientLightColor;
        public string TB_SceneLight0Color;
        public string TB_SceneLight0Rotation;
        public string TB_SceneLight1Color;
        public string TB_SceneLight1Rotation;
        public string TB_PoseTranslation;
        public string TB_PoseRotation;
        public string TB_PoseScale;
        public string TB_ExportedFromVersion;
        public string TB_CameraTranslation;
        public string TB_CameraRotation;
        public string TB_FlyMode;

        [ContextMenu("Apply Environment")]
        public void ApplyEnvironment()
        {
            EnvironmentSetup.ApplyEnvironment(this, Resources.Load<TextAsset>("environments_json"));
        }
    }
}