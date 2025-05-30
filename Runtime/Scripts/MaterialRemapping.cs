using UnityEngine;
using System.Collections.Generic;

[System.Serializable]
public class MaterialEntry
{
    public string key;
    public Material material;
}

public class MaterialRemapping : ScriptableObject
{
    [SerializeField] private List<MaterialEntry> entries = new ();
    private Dictionary<string, Material> nameDictionary;
    private Dictionary<string, string> guidDictionary = new()
    {
        { "f72ec0e7-a844-4e38-82e3-140c44772699", "OilPaint" },
        { "c515dad7-4393-4681-81ad-162ef052241b", "OilPaint" },
        { "f5c336cf-5108-4b40-ade9-c687504385ab", "Ink" },
        { "c0012095-3ffd-4040-8ee1-fc180d346eaa", "Ink" },
        { "75b32cf0-fdd6-4d89-a64b-e2a00b247b0f", "ThickPaint" },
        { "fdf0326a-c0d1-4fed-b101-9db0ff6d071f", "ThickPaint" },
        { "b67c0e81-ce6d-40a8-aeb0-ef036b081aa3", "WetPaint" },
        { "dea67637-cd1a-27e4-c9b1-52f4bbcb84e5", "WetPaint" },
        { "429ed64a-4e97-4466-84d3-145a861ef684", "Marker" },
        { "d90c6ad8-af0f-4b54-b422-e0f92abe1b3c", "TaperedMarker" },
        { "1a26b8c0-8a07-4f8a-9fac-d2ef36e0cad0", "TaperedMarker_Flat" },
        { "0d3889f3-3ede-470c-8af4-de4813306126", "DoubleTaperedMarker" },
        { "cf019139-d41c-4eb0-a1d0-5cf54b0a42f3", "Highlighter" },
        { "2d35bcf0-e4d8-452c-97b1-3311be063130", "Flat" },
        { "280c0a7a-aad8-416c-a7d2-df63d129ca70", "Flat" },
        { "55303bc4-c749-4a72-98d9-d23e68e76e18", "FlatDeprecated" },
        { "b468c1fb-f254-41ed-8ec9-57030bc5660c", "TaperedFlat" },
        { "c8ccb53d-ae13-45ef-8afb-b730d81394eb", "TaperedFlat" },
        { "0d3889f3-3ede-470c-8af4-f44813306126", "DoubleTaperedFlat" },
        { "accb32f5-4509-454f-93f8-1df3fd31df1b", "SoftHighlighter" },
        { "2241cd32-8ba2-48a5-9ee7-2caef7e9ed62", "Light" },
        { "cb92b597-94ca-4255-b017-0e3f42f12f9e", "Fire" },
        { "02ffb866-7fb2-4d15-b761-1012cefb1360", "Embers" },
        { "70d79cca-b159-4f35-990c-f02193947fe8", "Smoke" },
        { "d902ed8b-d0d1-476c-a8de-878a79e3a34c", "Snow" },
        { "ad1ad437-76e2-450d-a23a-e17f8310b960", "Rainbow" },
        { "0eb4db27-3f82-408d-b5a1-19ebd7d5b711", "Stars" },
        { "d229d335-c334-495a-a801-660ac8a87360", "VelvetInk" },
        { "10201aa3-ebc2-42d8-84b7-2e63f6eeb8ab", "Waveform" },
        { "8dc4a70c-d558-4efd-a5ed-d4e860f40dc3", "Splatter" },
        { "7a1c8107-50c5-4b70-9a39-421576d6617e", "Splatter" },
        { "d0262945-853c-4481-9cbd-88586bed93cb", "DuctTape" },
        { "3ca16e2f-bdcd-4da2-8631-dcef342f40f1", "DuctTape" },
        { "f1114e2e-eb8d-4fde-915a-6e653b54e9f5", "Paper" },
        { "759f1ebd-20cd-4720-8d41-234e0da63716", "Paper" },
        { "1161af82-50cf-47db-9706-0c3576d43c43", "CoarseBristles" },
        { "79168f10-6961-464a-8be1-57ed364c5600", "CoarseBristles" },
        { "5347acf0-a8e2-47b6-8346-30c70719d763", "WigglyGraphite" },
        { "e814fef1-97fd-7194-4a2f-50c2bb918be2", "WigglyGraphite" },
        { "f6e85de3-6dcc-4e7f-87fd-cee8c3d25d51", "Electricity" },
        { "44bb800a-fbc3-4592-8426-94ecb05ddec3", "Streamers" },
        { "dce872c2-7b49-4684-b59b-c45387949c5c", "Hypercolor" },
        { "e8ef32b1-baa8-460a-9c2c-9cf8506794f5", "Hypercolor" },
        { "89d104cd-d012-426b-b5b3-bbaee63ac43c", "Bubbles" },
        { "b2ffef01-eaaa-4ab5-aa64-95a2c4f5dbc6", "NeonPulse" },
        { "700f3aa8-9a7c-2384-8b8a-ea028905dd8c", "CelVinyl" },
        { "6a1cf9f9-032c-45ec-9b6e-a6680bee32e9", "HyperGrid" },
        { "4391aaaa-df81-4396-9e33-31e4e4930b27", "LightWire" },
        { "0f0ff7b2-a677-45eb-a7d6-0cd7206f4816", "ChromaticWave" },
        { "6a1cf9f9-032c-45ec-9b1d-a6680bee30f7", "Dots" },
        { "e0abbc80-0f80-e854-4970-8924a0863dcc", "Petal" },
        { "2f212815-f4d3-c1a4-681a-feeaf9c6dc37", "Icing" },
        { "4391385a-df73-4396-9e33-31e4e4930b27", "Toon" },
        { "4391385a-cf83-4396-9e33-31e4e4930b27", "Wire" },
        { "cf7f0059-7aeb-53a4-2b67-c83d863a9ffa", "Spikes" },
        { "d381e0f5-3def-4a0d-8853-31e9200bcbda", "Lofted" },
        { "4391aaaa-df73-4396-9e33-31e4e4930b27", "Disco" },
        { "1caa6d7d-f015-3f54-3a4b-8b5354d39f81", "Comet" },
        { "faaa4d44-fcfb-4177-96be-753ac0421ba3", "ShinyHull" },
        { "79348357-432d-4746-8e29-0e25c112e3aa", "MatteHull" },
        { "a8fea537-da7c-4d4b-817f-24f074725d6d", "UnlitHull" },
        { "c8313697-2563-47fc-832e-290f4c04b901", "DiamondHull" },
        { "ea19de07-d0c0-4484-9198-18489a3c1487", "Leaves" },
        { "d1d991f2-e7a0-4cf1-b328-f57e915e6260", "DotMarker" },
        { "c33714d1-b2f9-412e-bd50-1884c9d46336", "Plasma" },
        { "0077f88c-d93a-42f3-b59b-b31c50cdb414", "Taffy" },
        { "232998f8-d357-47a2-993a-53415df9be10", "BlocksGem" },
        { "3d813d82-5839-4450-8ddc-8e889ecd96c7", "BlocksGlass" },
        { "0e87b49c-6546-3a34-3a44-8a556d7d6c3e", "BlocksBasic" },
        { "f86a096c-2f4f-4f9d-ae19-81b99f2944e0", "PbrTemplate" },
        { "19826f62-42ac-4a9e-8b77-4231fbd0cfbf", "PbrTransparentTemplate" },
        { "0ad58bbd-42bc-484e-ad9a-b61036ff4ce7", "EnvironmentDiffuse" },
        { "d01d9d6c-9a61-4aba-8146-5891fafb013b", "EnvironmentDiffuseLightMap" },
        { "1b897b7e-9b76-425a-b031-a867c48df409", "Gouache" },
        { "4465b5ef-3605-bec4-2b3e-6b04508ddb6b", "Gouache" },
        { "8e58ceea-7830-49b4-aba9-6215104ab52a", "MylarTube" },
        { "03a529e1-f519-3dd4-582d-2d5cd92c3f4f", "Rain" },
        { "725f4c6a-6427-6524-29ab-da371924adab", "DryBrush" },
        { "ddda8745-4bb5-ac54-88b6-d1480370583e", "LeakyPen" },
        { "50e99447-3861-05f4-697d-a1b96e771b98", "Sparks" },
        { "7136a729-1aab-bd24-f8b2-ca88b6adfb67", "Wind" },
        { "a8147ce1-005e-abe4-88e8-09a1eaadcc89", "RisingBubbles" },
        { "9568870f-8594-60f4-1b20-dfbc8a5eac0e", "TaperedWire" },
        { "2e03b1bf-3ebd-4609-9d7e-f4cafadc4dfa", "SquarePaper" },
        { "39ee7377-7a9e-47a7-a0f8-0c77712f75d3", "ThickGeometry" },
        { "2c1a6a63-6552-4d23-86d7-58f6fba8581b", "Wireframe" },
        { "61d2ef63-ed60-49b3-85fb-7267b7d234f2", "CandyCane" },
        { "20a0bf1a-a96e-44e5-84ac-9823d2d65023", "HolidayTree" },
        { "2b65cd94-9259-4f10-99d2-d54b6664ac33", "Snowflake" },
        { "22d4f434-23e4-49d9-a9bd-05798aa21e58", "Braid3" },
        { "f28c395c-a57d-464b-8f0b-558c59478fa3", "Muscle" },
        { "99aafe96-1645-44cd-99bd-979bc6ef37c5", "Guts" },
        { "53d753ef-083c-45e1-98e7-4459b4471219", "Fire2" },
        { "9871385a-df73-4396-9e33-31e4e4930b27", "TubeToonInverted" },
        { "4391ffaa-df73-4396-9e33-31e4e4930b27", "FacetedTube" },
        { "6a1cf9f9-032c-45ec-9b6e-a6680bee30f7", "WaveformParticles" },
        { "eba3f993-f9a1-4d35-b84e-bb08f48981a4", "BubbleWand" },
        { "6a1cf9f9-032c-45ec-311e-a6680bee32e9", "DanceFloor" },
        { "0f5820df-cb6b-4a6c-960e-56e4c8000eda", "WaveformTube" },
        { "492b36ff-b337-436a-ba5f-1e87ee86747e", "Drafting" },
        { "f0a2298a-be80-432c-9fee-a86dcc06f4f9", "SingleSided" },
        { "f4a0550c-332a-4e1a-9793-b71508f4a454", "DoubleFlat" },
        { "c1c9b26d-673a-4dc6-b373-51715654ab96", "TubeAdditive" },
        { "a555b809-2017-46cb-ac26-e63173d8f45e", "Feather" },
        { "84d5bbb2-6634-8434-f8a7-681b576b4664", "DuctTapeGeometry" },
        { "3d9755da-56c7-7294-9b1d-5ec349975f52", "TaperedHueShift" },
        { "1cf94f63-f57a-4a1a-ad14-295af4f5ab5c", "Lacewing" },
        { "c86c058d-1bda-2e94-08db-f3d6a96ac4a1", "MarbledRainbow" },
        { "fde6e778-0f7a-e584-38d6-89d44cee59f6", "Charcoal" },
        { "f8ba3d18-01fc-4d7b-b2d9-b99d10b8e7cf", "KeijiroTube" },
        { "c5da2e70-a6e4-63a4-898c-5cfedef09c97", "Lofted" },
        { "62fef968-e842-3224-4a0e-1fdb7cfb745c", "Wire" },
        { "d120944d-772f-4062-99c6-46a6f219eeaf", "WaveformFFT" },
        { "d9cc5e99-ace1-4d12-96e0-4a7c18c99cfc", "Fairy" },
        { "bdf65db2-1fb7-4202-b5e0-c6b5e3ea851e", "Space" },
        { "30cb9af6-be41-4872-8f3e-cbff63fe3db8", "Digital" },
        { "abfbb2aa-70b4-4a5c-8126-8eedda2b3628", "Race" },
        { "355b3579-bf1d-4ff5-a200-704437fe684b", "SmoothHull" },
        { "7259cce5-41c1-ec74-c885-78af28a31d95", "Leaves2" },
        { "7c972c27-d3c2-8af4-7bf8-5d9db8f0b7bb", "InkGeometry" },
        { "7ae1f880-a517-44a0-99f9-1cab654498c6", "ConcaveHull" },
        { "d3f3b18a-da03-f694-b838-28ba8e749a98", "3DPrintingBrush" }
    };

    public Material GetMaterialByName(string key)
    {
        if (nameDictionary == null)
        {
            InitializeDictionaries();
        }
        return nameDictionary[key];
    }

    public Material GetMaterialByGuid(string guid)
    {
        string name = guidDictionary[guid];
        return GetMaterialByName($"ob-{name}");
    }

    private void OnValidate()
    {
        InitializeDictionaries();
    }

    private void InitializeDictionaries()
    {
        nameDictionary = new Dictionary<string, Material>();
        foreach (MaterialEntry entry in entries)
        {
            string key = $"ob-{entry.key}";
            if (nameDictionary.ContainsKey(key))
            {
                Debug.LogError($"Duplicate key found in MaterialRemapping: {entry.key}");
            }
            else
            {
                nameDictionary.Add(key, entry.material);
            }
        }
    }
}
