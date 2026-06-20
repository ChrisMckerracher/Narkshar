using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace NarksharLauncher;

public sealed class NarksharUpdater
{
    private const string AssetsZipUrl = "https://github.com/ChrisMckerracher/Narkshar/archive/refs/heads/main.zip";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private readonly string _wowRoot;
    private readonly string _stateDir;
    private readonly string _installedManifestPath;

    public NarksharUpdater(string wowRoot)
    {
        _wowRoot = Path.GetFullPath(wowRoot);
        _stateDir = Path.Combine(_wowRoot, ".narkshar");
        _installedManifestPath = Path.Combine(_stateDir, "installed-manifest.json");
    }

    public bool HasWowExe => File.Exists(Path.Combine(_wowRoot, "Wow.exe"));

    public async Task<UpdateResult> UpdateAsync(IProgress<UpdateProgress> progress, CancellationToken cancellationToken)
    {
        if (!HasWowExe)
        {
            return new UpdateResult { CanPlay = false, Message = "Put this launcher beside Wow.exe." };
        }

        var tempRoot = Path.Combine(Path.GetTempPath(), "NarksharLauncher", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);

        try
        {
            progress.Report(new UpdateProgress { Message = "Downloading Narkshar assets...", Percent = 5 });
            var zipPath = Path.Combine(tempRoot, "narkshar-main.zip");
            await DownloadAsync(zipPath, cancellationToken);

            progress.Report(new UpdateProgress { Message = "Extracting assets...", Percent = 25 });
            var extractRoot = Path.Combine(tempRoot, "extract");
            ZipFile.ExtractToDirectory(zipPath, extractRoot);

            var repoRoot = FindExtractedRepoRoot(extractRoot);
            var manifest = await ReadManifestAsync(Path.Combine(repoRoot, "manifest.json"), cancellationToken);

            progress.Report(new UpdateProgress { Message = "Removing stale managed files...", Percent = 35 });
            await RemoveStaleManagedFilesAsync(manifest, cancellationToken);

            var total = Math.Max(1, manifest.Files.Count);
            for (var i = 0; i < manifest.Files.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var file = manifest.Files[i];
                var percent = 35 + (int)Math.Round((i + 1) * 55.0 / total);
                progress.Report(new UpdateProgress { Message = $"Installing {file.Path}", Percent = percent });
                await InstallFileAsync(repoRoot, file, cancellationToken);
            }

            progress.Report(new UpdateProgress { Message = "Saving install state...", Percent = 95 });
            Directory.CreateDirectory(_stateDir);
            await File.WriteAllTextAsync(_installedManifestPath, JsonSerializer.Serialize(manifest, JsonOptions), cancellationToken);

            return new UpdateResult
            {
                Updated = true,
                CanPlay = true,
                Message = $"Narkshar assets current ({manifest.Version})."
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
        finally
        {
            TryDeleteDirectory(tempRoot);
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

    private static async Task DownloadAsync(string zipPath, CancellationToken cancellationToken)
    {
        using var http = new HttpClient();
        http.DefaultRequestHeaders.UserAgent.ParseAdd("NarksharLauncher/1.0");
        await using var remote = await http.GetStreamAsync(AssetsZipUrl, cancellationToken);
        await using var local = File.Create(zipPath);
        await remote.CopyToAsync(local, cancellationToken);
    }

    private static string FindExtractedRepoRoot(string extractRoot)
    {
        var manifest = Directory.EnumerateFiles(extractRoot, "manifest.json", SearchOption.AllDirectories).FirstOrDefault();
        if (manifest is null)
        {
            throw new InvalidOperationException("Downloaded archive did not contain manifest.json.");
        }

        return Path.GetDirectoryName(manifest) ?? throw new InvalidOperationException("Invalid manifest path.");
    }

    private static async Task<AssetManifest> ReadManifestAsync(string manifestPath, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(manifestPath);
        var manifest = await JsonSerializer.DeserializeAsync<AssetManifest>(stream, cancellationToken: cancellationToken);
        if (manifest is null || manifest.Files.Count == 0)
        {
            throw new InvalidOperationException("Downloaded manifest is empty.");
        }

        foreach (var file in manifest.Files)
        {
            ValidateManifestPath(file.Path);
        }

        return manifest;
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
            if (newPaths.Contains(normalized))
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

    private async Task InstallFileAsync(string repoRoot, AssetFile file, CancellationToken cancellationToken)
    {
        var source = ResolveUnderRoot(repoRoot, file.Path);
        if (!File.Exists(source))
        {
            throw new FileNotFoundException("Manifest file missing from archive.", file.Path);
        }

        var sourceInfo = new FileInfo(source);
        if (sourceInfo.Length != file.Size)
        {
            throw new InvalidOperationException($"Size mismatch for {file.Path}.");
        }

        var sourceHash = await Sha256Async(source, cancellationToken);
        if (!sourceHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Hash mismatch for {file.Path}.");
        }

        var destination = ResolveClientDestination(file.Path);
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        File.Copy(source, destination, overwrite: true);

        var destinationHash = await Sha256Async(destination, cancellationToken);
        if (!destinationHash.Equals(file.Sha256, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Installed file verification failed for {file.Path}.");
        }
    }

    private string ResolveClientDestination(string manifestPath)
    {
        var normalized = NormalizeManifestPath(manifestPath);
        const string clientPrefix = "client/";
        if (!normalized.StartsWith(clientPrefix, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Managed path must start with client/: {manifestPath}");
        }

        return ResolveUnderRoot(_wowRoot, normalized[clientPrefix.Length..]);
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

    private static void TryDeleteDirectory(string directory)
    {
        try
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
        catch
        {
            // Temp cleanup failure should not block playing.
        }
    }
}
