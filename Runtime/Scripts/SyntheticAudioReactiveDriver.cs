// Synthetic audio-reactive test driver.
//
// Feeds fake audio data into the GLOBAL shader properties that Open Brush's audio-reactive
// brushes consume (_WaveFormTex, _FFTTex, _BeatOutput, _BeatOutputAccum, _PeakBandLevels,
// _AudioVolume), so the ported shaders can be exercised in this package's own test scene
// WITHOUT running the host Open Brush VisualizerManager.
//
// The signal is a frequency sweep: a sine whose frequency ramps across [minFrequency,
// maxFrequency]. The waveform texture shows that sine, the FFT texture shows a single peak
// tracking the swept frequency, the four band levels light up as the sweep moves low -> high,
// and an optional rhythmic beat pulse drives the beat-reactive brushes.
//
// Drop it on any GameObject. Runs in Play mode and, via [ExecuteAlways], animates in the editor
// too (it forces Scene-view repaints while disabled-from-play).

using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
[AddComponentMenu("Open Brush Unity Tools/Synthetic Audio-Reactive Driver")]
public class SyntheticAudioReactiveDriver : MonoBehaviour
{
    static readonly int s_WaveFormTex     = Shader.PropertyToID("_WaveFormTex");
    static readonly int s_FFTTex          = Shader.PropertyToID("_FFTTex");
    static readonly int s_BeatOutput      = Shader.PropertyToID("_BeatOutput");
    static readonly int s_BeatOutputAccum = Shader.PropertyToID("_BeatOutputAccum");
    static readonly int s_PeakBandLevels  = Shader.PropertyToID("_PeakBandLevels");
    static readonly int s_AudioVolume     = Shader.PropertyToID("_AudioVolume");

    [Header("Frequency sweep")]
    [Tooltip("Low end of the sweep, Hz.")]
    public float minFrequency = 20f;
    [Tooltip("High end of the sweep, Hz.")]
    public float maxFrequency = 4000f;
    [Tooltip("Seconds for one sweep across the range.")]
    public float sweepDuration = 8f;
    [Tooltip("Sweep up then back down, vs. repeating low -> high.")]
    public bool pingPong = true;
    [Tooltip("Sweep logarithmically (more musical) vs. linearly.")]
    public bool logarithmic = true;

    [Header("Synthetic signal")]
    [Range(64, 1024)] public int resolution = 256;
    [Tooltip("Notional sample rate used to map Hz -> cycles across the waveform texture.")]
    public float sampleRate = 44100f;
    [Range(0f, 1f)] public float amplitude = 1f;

    [Header("Beat pulse")]
    public bool generateBeat = true;
    [Tooltip("Beat pulses per second.")]
    public float beatsPerSecond = 2f;
    [Tooltip("Higher = sharper, more percussive pulse.")]
    public float beatSharpness = 6f;
    [Tooltip("How fast _BeatOutputAccum advances (the scroll / time driver).")]
    public float accumulationRate = 1f;

    [Header("Cleanup")]
    [Tooltip("Reset the globals to silence when this component is disabled.")]
    public bool clearOnDisable = true;

    [Header("Status (read-only)")]
    public float currentFrequency;
    [Range(0f, 1f)] public float sweepPosition;

    Texture2D _waveTex;
    Texture2D _fftTex;
    Color[] _wavePixels;
    Color[] _fftPixels;
    float[] _fftPeakHold;
    Vector4 _beatAccum;
    float _time;

    const float kAccumWrap = 1000f;     // wrap accum to keep float precision over long runs
    const float kPeakHoldDecay = 0.92f; // FFT peak-hold trail decay per frame

#if UNITY_EDITOR
    double _lastEditorTime;
#endif

    void OnEnable()
    {
        _time = 0f;
        _beatAccum = Vector4.zero;
        Allocate();
#if UNITY_EDITOR
        _lastEditorTime = EditorApplication.timeSinceStartup;
        if (!Application.isPlaying)
            EditorApplication.update += EditorTick;
#endif
    }

    void OnDisable()
    {
#if UNITY_EDITOR
        EditorApplication.update -= EditorTick;
#endif
        if (clearOnDisable)
            ClearGlobals();
    }

    void Update()
    {
        if (Application.isPlaying)
            Tick(Time.deltaTime);
    }

#if UNITY_EDITOR
    void EditorTick()
    {
        if (this == null) { EditorApplication.update -= EditorTick; return; }
        double now = EditorApplication.timeSinceStartup;
        float dt = (float)(now - _lastEditorTime);
        _lastEditorTime = now;
        if (dt <= 0f || dt > 0.5f) dt = 1f / 60f;
        Tick(dt);
        SceneView.RepaintAll();
    }
#endif

    void Allocate()
    {
        resolution = Mathf.Clamp(resolution, 64, 1024);
        if (_waveTex != null && _waveTex.width == resolution)
            return;

        _waveTex = new Texture2D(resolution, 1, TextureFormat.RGBAFloat, false)
        {
            name = "Synthetic WaveForm",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Repeat   // ChromaticWave samples uv.x * 1.8 / 2.4 (> 1)
        };
        _fftTex = new Texture2D(resolution, 1, TextureFormat.RGBAFloat, false)
        {
            name = "Synthetic FFT",
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp
        };
        _wavePixels = new Color[resolution];
        _fftPixels = new Color[resolution];
        _fftPeakHold = new float[resolution];
    }

    void Tick(float dt)
    {
        Allocate();
        _time += dt;

        float t = sweepDuration > 0.0001f ? _time / sweepDuration : 0f;
        float pos = pingPong ? Mathf.PingPong(t, 1f) : Mathf.Repeat(t, 1f);
        sweepPosition = pos;

        float freq = (logarithmic && minFrequency > 0f)
            ? minFrequency * Mathf.Pow(maxFrequency / minFrequency, pos)
            : Mathf.Lerp(minFrequency, maxFrequency, pos);
        currentFrequency = freq;

        Vector4 bands = WriteFFT(pos);
        WriteWaveform(freq, pos);
        WriteBeat(dt);

        Shader.SetGlobalTexture(s_WaveFormTex, _waveTex);
        Shader.SetGlobalTexture(s_FFTTex, _fftTex);
        Shader.SetGlobalVector(s_PeakBandLevels, bands);
    }

    void WriteWaveform(float freq, float pos)
    {
        // Cycles of the sine across the texture window, clamped below Nyquist.
        float cycles = Mathf.Clamp(freq * resolution / Mathf.Max(1f, sampleRate), 0f, resolution * 0.5f);
        float lowGain = Mathf.Clamp01(1f - pos);  // low-pass channel: strong at low freq
        float highGain = Mathf.Clamp01(pos);       // high-pass channel: strong at high freq

        for (int i = 0; i < resolution; i++)
        {
            float x = (resolution > 1) ? (float)i / (resolution - 1) : 0f;
            float s = Mathf.Sin(2f * Mathf.PI * cycles * x) * amplitude;
            // Stored as 0.5 +/- s, so shaders doing (tex - 0.5) recenter to +/- amplitude * 0.5.
            float raw = 0.5f + 0.5f * s;
            _wavePixels[i] = new Color(
                raw,                        // r = waveform
                raw,                        // g = smoothed (same here)
                0.5f + 0.5f * s * lowGain,  // b = low-pass
                0.5f + 0.5f * s * highGain  // a = high-pass
            );
        }
        _waveTex.SetPixels(_wavePixels);
        _waveTex.Apply(false);
    }

    Vector4 WriteFFT(float pos)
    {
        float peakBin = pos * (resolution - 1);
        float sigma = Mathf.Max(1f, resolution * 0.02f);
        var bands = Vector4.zero;

        for (int i = 0; i < resolution; i++)
        {
            float d = i - peakBin;
            float v = Mathf.Exp(-(d * d) / (2f * sigma * sigma));   // narrow peak at swept freq
            _fftPeakHold[i] = Mathf.Max(v, _fftPeakHold[i] * kPeakHoldDecay);
            int band = Mathf.Clamp(Mathf.FloorToInt((float)i / resolution * 4f), 0, 3);
            bands[band] = Mathf.Max(bands[band], v);
            _fftPixels[i] = new Color(
                v,                  // r = FFT
                Mathf.Pow(v, 0.6f), // g = power curve (brightened)
                _fftPeakHold[i],    // b = peak FFT (trailing hold)
                0f                  // a = band level, filled below
            );
        }
        // Second pass: write the resolved per-band level into alpha so .a is flat within a band.
        for (int i = 0; i < resolution; i++)
        {
            int band = Mathf.Clamp(Mathf.FloorToInt((float)i / resolution * 4f), 0, 3);
            Color c = _fftPixels[i];
            c.a = bands[band];
            _fftPixels[i] = c;
        }
        _fftTex.SetPixels(_fftPixels);
        _fftTex.Apply(false);
        return bands;
    }

    void WriteBeat(float dt)
    {
        Vector4 beat = Vector4.zero;
        if (generateBeat)
        {
            // Per-band pulse with small phase offsets so the four channels differ.
            beat = new Vector4(Pulse(0.00f), Pulse(0.10f), Pulse(0.20f), Pulse(0.30f));
        }

        _beatAccum += beat * (dt * accumulationRate);
        _beatAccum = new Vector4(
            Mathf.Repeat(_beatAccum.x, kAccumWrap),
            Mathf.Repeat(_beatAccum.y, kAccumWrap),
            Mathf.Repeat(_beatAccum.z, kAccumWrap),
            Mathf.Repeat(_beatAccum.w, kAccumWrap)
        );

        Shader.SetGlobalVector(s_BeatOutput, beat);
        Shader.SetGlobalVector(s_BeatOutputAccum, _beatAccum);
        float vol = generateBeat ? Mathf.Max(beat.x, beat.w) : amplitude;
        Shader.SetGlobalVector(s_AudioVolume, new Vector4(vol, vol, vol, vol));
    }

    // Instant attack, decaying tail; beatsPerSecond pulses per second.
    float Pulse(float offset)
    {
        float phase = Mathf.Repeat((_time + offset) * beatsPerSecond, 1f);
        return Mathf.Pow(1f - phase, Mathf.Max(0.01f, beatSharpness));
    }

    void ClearGlobals()
    {
        Shader.SetGlobalTexture(s_WaveFormTex, Texture2D.blackTexture);
        Shader.SetGlobalTexture(s_FFTTex, Texture2D.blackTexture);
        Shader.SetGlobalVector(s_BeatOutput, Vector4.zero);
        Shader.SetGlobalVector(s_BeatOutputAccum, Vector4.zero);
        Shader.SetGlobalVector(s_PeakBandLevels, Vector4.zero);
        Shader.SetGlobalVector(s_AudioVolume, Vector4.zero);
    }

    void OnValidate()
    {
        minFrequency = Mathf.Max(1f, minFrequency);
        maxFrequency = Mathf.Max(minFrequency + 1f, maxFrequency);
        sweepDuration = Mathf.Max(0.01f, sweepDuration);
        beatsPerSecond = Mathf.Max(0.01f, beatsPerSecond);
        resolution = Mathf.Clamp(resolution, 64, 1024);
    }
}
