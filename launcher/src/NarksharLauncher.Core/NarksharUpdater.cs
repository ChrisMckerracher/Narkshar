using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;

namespace NarksharLauncher;

public sealed class NarksharUpdater
{
    private const string DefaultAssetBaseUrl = "https://narkshar-client-assets.s3.us-east-1.amazonaws.com/";
    private const string ManifestPath = "client/manifest.json";
    private const string ClientPrefix = "client/";
    private const string LauncherManifestPath = "client/NarksharLauncher.exe";
    private const string StagedLauncherFileName = "NarksharLauncher.new.exe";

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private static readonly HashSet<string> ProtectedStalePaths = new(StringComparer.OrdinalIgnoreCase)
    {
        "client/Wow.exe",
        LauncherManifestPath
    };

    private readonly string _wowRoot;
    private readonly string _stateDir;
    private readonly string _installedManifestPath;
    private readonly string _downloadDir;
    private readonly HttpClient _http;
    private readonly Uri _assetBaseUri;

    public NarksharUpdater(string wowRoot)
        : this(wowRoot, new HttpClient(), ResolveDefaultAssetBaseUri(wowRoot))
    {
    }

    public NarksharUpdater(string wowRoot, HttpClient http, Uri assetBaseUri)
    {
        _wowRoot = Path.GetFullPath(wowRoot);
        _stateDir = Path.Combine(_wowRoot, ".narkshar");
        _installedManifestPath = Path.Combine(_stateDir, "installed-manifest.json");
        _downloadDir = Path.Combine(_stateDir, "downloads");
        _http = http;
        _assetBaseUri = assetBaseUri;
    }

    public bool HasWowExe => File.Exists(Path.Combine(_wowRoot, "Wow.exe"));

    public async Task<UpdateResult> UpdateAsync(IProgress<UpdateProgress> progress, CancellationToken cancellationToken)
    {
        if (!HasWowExe)
        {
            return new UpdateResult { CanPlay = false, Message = "Put this launcher beside Wow.exe." };
        }

        try
        {
            progress.Report(new UpdateProgress { Message = "Downloading Narkshar manifest...", Percent = 5 });
            var manifest = await DownloadManifestAsync(cancellationToken);

            progress.Report(new UpdateProgress { Message = "Removing stale managed files...", Percent = 15 });
            await RemoveStaleManagedFilesAsync(manifest, cancellationToken);

            var total = Math.Max(1, manifest.Files.Count);
            var downloaded = 0;
            var stagedLauncher = false;
            for (var i = 0; i < manifest.Files.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var file = manifest.Files[i];
                var percent = 15 + (int)Math.Round((i + 1) * 75.0 / total);
                if (await LocalFileMatchesAsync(file, cancellationToken))
                {
                    stagedLauncher |= IsLauncherPath(file.Path) && await StagedLauncherMatchesAsync(file, cancellationToken);
                    progress.Report(new UpdateProgress { Message = $"Current {file.Path}", Percent = percent });
                    continue;
                }

                progress.Report(new UpdateProgress { Message = $"Downloading {file.Path}", Percent = percent });
                var result = await DownloadAndInstallFileAsync(file, cancellationToken);
                downloaded++;
                stagedLauncher |= result == InstallResult.StagedLauncher;
            }

            progress.Report(new UpdateProgress { Message = "Saving install state...", Percent = 95 });
            Directory.CreateDirectory(_stateDir);
            await File.WriteAllTextAsync(_installedManifestPath, JsonSerializer.Serialize(manifest, JsonOptions), cancellationToken);

            var message = stagedLauncher
                ? $"Narkshar assets current ({manifest.Version}). Launcher update staged as {StagedLauncherFileName}; close this launcher and run that file to update."
                : downloaded == 0
                    ? $"Narkshar assets already current ({manifest.Version})."
                    : $"Narkshar assets current ({manifest.Version}).";

            return new UpdateResult
            {
                Updated = true,
                CanPlay = true,
                Message = message
            };
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            return new UpdateResult
            {
                Updated = false,
                CanPlay = true,
                Message = $"Update failed. You can play with existing files. {ex.Message}"
            };
        }
    }

    public void LaunchWow()
    {
        var wowExe = Path.Combine(_wowRoot, "Wow.exe");
        var info = new ProcessStartInfo
        {
            FileName = wowExe,
            WorkingDirectory = _wowRoot,
            UseShellExecute = true
        };
        Process.Start(info);
    }

    private async Task<AssetManifest> DownloadManifestAsync(CancellationToken cancellationToken)
    {
        using var response = await _http.GetAsync(BuildAssetUri(ManifestPath), cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        var manifest = await JsonSerializer.DeserializeAsync<AssetManifest>(stream, cancellationToken: cancellationToken);
        if (manifest is null || manifest.Files.Count == 0)
        {
            throw new InvalidOperationException("Downloaded manifest is empty.");
        }

        ValidateManifest(manifest);
        return manifest;
    }

    private static async Task<AssetManifest> ReadManifestAsync(string manifestPath, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(manifestPath);
        var manifest = await JsonSerializer.DeserializeAsync<AssetManifest>(stream, cancellationToken: cancellationToken);
        if (manifest is null || manifest.Files.Count == 0)
        {
            throw new InvalidOperationException("Downloaded manifest is empty.");
        }

        ValidateManifest(manifest);
        return manifest;
    }

    private static void ValidateManifest(AssetManifest manifest)
    {
        foreach (var file in manifest.Files)
        {
            var normalized = NormalizeManifestPath(file.Path);
            if (!normalized.StartsWith(ClientPrefix, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException($"Managed path must start with client/: {file.Path}");
            }
        }
    }

    private async Task RemoveStaleManagedFilesAsync(AssetManifest newManifest, CancellationToken cancellationToken)
    {
        if (!File.Exists(_installedManifestPath))
        {
            return;
        }

        var oldManifest = await ReadManifestAsync(_installedManifestPath, cancellationToken);
        var newPaths = new HashSet<string>(newManifest.Files.Select(f => NormalizeManifestPath(f.Path)), StringComparer.OrdinalIgnoreCase);

        foreach (var oldFile in oldManifest.Files)
        {
            var normalized = NormalizeManifestPath(oldFile.Path);
            if (newPaths.Contains(normalized) || ProtectedStalePaths.Contains(normalized))
            {
                continue;
            }

            var destination = ResolveClientDestination(oldFile.Path);
            if (File.Exists(destination))
            {
                File.Delete(destination);
                DeleteEmptyParents(Path.GetDirectoryName(destination));
            }
        }
    }

    private async Task<bool> LocalFileMatchesAsync(AssetFile file, CancellationToken cancellationToken)
    {
        var destination = GetVerificationDestination(file.Path);
        if (!File.Exists(destination))
        {
            return false;
        }

        var destinationInfo = new FileInfo(destination);
        if (destinationInfo.Length != file.Size)
        {
            return false;
        }

        var destinationHash = await Sha256Async(destination, cancellationToken);
        return destinationHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase);
    }

    private async Task<bool> StagedLauncherMatchesAsync(AssetFile file, CancellationToken cancellationToken)
    {
        if (!IsLauncherPath(file.Path))
        {
            return false;
        }

        var currentLauncher = ResolveClientDestination(file.Path);
        if (File.Exists(currentLauncher))
        {
            var currentInfo = new FileInfo(currentLauncher);
            if (currentInfo.Length == file.Size)
            {
                var currentHash = await Sha256Async(currentLauncher, cancellationToken);
                if (currentHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }
            }
        }

        var stagedLauncher = Path.Combine(_wowRoot, StagedLauncherFileName);
        if (!File.Exists(stagedLauncher))
        {
            return false;
        }

        var stagedInfo = new FileInfo(stagedLauncher);
        if (stagedInfo.Length != file.Size)
        {
            return false;
        }

        var stagedHash = await Sha256Async(stagedLauncher, cancellationToken);
        return stagedHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase);
    }

    private async Task<InstallResult> DownloadAndInstallFileAsync(AssetFile file, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_downloadDir);
        var staged = Path.Combine(_downloadDir, HashFileName(file.Path));

        using (var response = await _http.GetAsync(BuildAssetUri(file.Path), cancellationToken))
        {
            response.EnsureSuccessStatusCode();
            await using var remote = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var local = File.Create(staged);
            await remote.CopyToAsync(local, cancellationToken);
        }

        var stagedInfo = new FileInfo(staged);
        if (stagedInfo.Length != file.Size)
        {
            throw new InvalidOperationException($"Size mismatch for {file.Path}.");
        }

        var stagedHash = await Sha256Async(staged, cancellationToken);
        if (!stagedHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Hash mismatch for {file.Path}.");
        }

        var destination = ResolveInstallDestination(file.Path);
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        File.Move(staged, destination, overwrite: true);

        if (!await LocalFileMatchesAsync(file, cancellationToken))
        {
            throw new InvalidOperationException($"Installed file verification failed for {file.Path}.");
        }

        return IsLauncherPath(file.Path) ? InstallResult.StagedLauncher : InstallResult.Installed;
    }

    private string GetVerificationDestination(string manifestPath)
    {
        var destination = ResolveClientDestination(manifestPath);
        if (!IsLauncherPath(manifestPath))
        {
            return destination;
        }

        var stagedLauncher = Path.Combine(_wowRoot, StagedLauncherFileName);
        return File.Exists(stagedLauncher) ? stagedLauncher : destination;
    }

    private string ResolveInstallDestination(string manifestPath)
    {
        if (IsLauncherPath(manifestPath))
        {
            return ResolveUnderRoot(_wowRoot, StagedLauncherFileName);
        }

        return ResolveClientDestination(manifestPath);
    }

    private string ResolveClientDestination(string manifestPath)
    {
        var normalized = NormalizeManifestPath(manifestPath);
        return ResolveUnderRoot(_wowRoot, normalized[ClientPrefix.Length..]);
    }

    private static string ResolveUnderRoot(string root, string relativePath)
    {
        ValidateManifestPath(relativePath);
        var resolved = Path.GetFullPath(Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar)));
        var fullRoot = Path.GetFullPath(root);
        if (!resolved.StartsWith(fullRoot.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Path escapes target root: {relativePath}");
        }

        return resolved;
    }

    private static void ValidateManifestPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) ||
            path.Contains('\\') ||
            path.Split('/').Any(part => part is "" or "." or "..") ||
            Path.IsPathRooted(path))
        {
            throw new InvalidOperationException($"Invalid manifest path: {path}");
        }
    }

    private static string NormalizeManifestPath(string path)
    {
        ValidateManifestPath(path);
        return path.Replace('\\', '/');
    }

    private Uri BuildAssetUri(string manifestPath)
    {
        return new Uri(_assetBaseUri, NormalizeManifestPath(manifestPath));
    }

    private static bool IsLauncherPath(string manifestPath)
    {
        return NormalizeManifestPath(manifestPath).Equals(LauncherManifestPath, StringComparison.OrdinalIgnoreCase);
    }

    private static string HashFileName(string manifestPath)
    {
        var bytes = SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(NormalizeManifestPath(manifestPath)));
        return Convert.ToHexString(bytes).ToLowerInvariant() + ".download";
    }

    private static Uri ResolveDefaultAssetBaseUri(string wowRoot)
    {
        var configured = Environment.GetEnvironmentVariable("NARKSHAR_ASSET_BASE_URL");
        if (string.IsNullOrWhiteSpace(configured))
        {
            var sidecar = Path.Combine(Path.GetFullPath(wowRoot), "NarksharLauncher.url");
            if (File.Exists(sidecar))
            {
                configured = File.ReadAllText(sidecar).Trim();
            }
        }

        if (string.IsNullOrWhiteSpace(configured))
        {
            configured = typeof(NarksharUpdater).Assembly
                .GetCustomAttributes<AssemblyMetadataAttribute>()
                .FirstOrDefault(attribute => attribute.Key == "NarksharAssetBaseUrl")
                ?.Value;
        }

        if (string.IsNullOrWhiteSpace(configured))
        {
            configured = DefaultAssetBaseUrl;
        }

        if (!configured.EndsWith("/", StringComparison.Ordinal))
        {
            configured += "/";
        }

        return new Uri(configured, UriKind.Absolute);
    }

    private static async Task<string> Sha256Async(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private void DeleteEmptyParents(string? directory)
    {
        while (!string.IsNullOrWhiteSpace(directory) && !Path.GetFullPath(directory).Equals(_wowRoot, StringComparison.OrdinalIgnoreCase))
        {
            if (Directory.EnumerateFileSystemEntries(directory).Any())
            {
                return;
            }

            Directory.Delete(directory);
            directory = Path.GetDirectoryName(directory);
        }
    }

    private enum InstallResult
    {
        Installed,
        StagedLauncher
    }
}
