using System.Text.Json.Serialization;

namespace NarksharLauncher;

public sealed class AssetManifest
{
    [JsonPropertyName("version")]
    public string Version { get; set; } = "";

    [JsonPropertyName("files")]
    public List<AssetFile> Files { get; set; } = [];
}

public sealed class AssetFile
{
    [JsonPropertyName("path")]
    public string Path { get; set; } = "";

    [JsonPropertyName("size")]
    public long Size { get; set; }

    [JsonPropertyName("sha256")]
    public string Sha256 { get; set; } = "";
}
