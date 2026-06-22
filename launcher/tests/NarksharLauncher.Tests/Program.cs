using System.Net;
using System.Security.Cryptography;
using System.Text;
using NarksharLauncher;

namespace NarksharLauncher.Tests;

internal static class Program
{
    private static async Task<int> Main()
    {
        var tests = new (string Name, Func<Task> Run)[]
        {
            ("matching local files do not download payloads", MatchingLocalFilesDoNotDownloadPayloads),
            ("missing files download from manifest paths", MissingFilesDownloadFromManifestPaths),
            ("invalid manifest paths are rejected", InvalidManifestPathsAreRejected),
            ("launcher update stages new exe", LauncherUpdateStagesNewExe),
            ("already staged launcher update is announced", AlreadyStagedLauncherUpdateIsAnnounced),
            ("stale cleanup preserves protected executables", StaleCleanupPreservesProtectedExecutables)
        };

        foreach (var test in tests)
        {
            await test.Run();
            Console.WriteLine($"PASS {test.Name}");
        }

        return 0;
    }

    private static async Task MatchingLocalFilesDoNotDownloadPayloads()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");
        WriteFile(Path.Combine(temp.Path, "Data", "patch-A.MPQ"), "asset");

        var manifest = ManifestJson(("client/Data/patch-A.MPQ", "asset"));
        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes(manifest)
        }, failOnMissing: true));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        var result = await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(result.CanPlay, "launcher should allow play");
        Assert(!File.Exists(Path.Combine(temp.Path, ".narkshar", "downloads", HashDownloadName("client/Data/patch-A.MPQ"))), "matching file should not download");
    }

    private static async Task MissingFilesDownloadFromManifestPaths()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");

        var manifest = ManifestJson(("client/Data/patch-A.MPQ", "asset"));
        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes(manifest),
            ["client/Data/patch-A.MPQ"] = Encoding.UTF8.GetBytes("asset")
        }));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(File.ReadAllText(Path.Combine(temp.Path, "Data", "patch-A.MPQ")) == "asset", "missing asset should be installed");
    }

    private static async Task InvalidManifestPathsAreRejected()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");

        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes("""
            {
              "version": "test",
              "files": [
                { "path": "../Wow.exe", "size": 1, "sha256": "00" }
              ]
            }
            """)
        }));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        var result = await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(result.CanPlay, "failed update should still allow play with existing files");
        Assert(result.Message.Contains("Invalid manifest path", StringComparison.Ordinal), "invalid path should be reported");
    }

    private static async Task LauncherUpdateStagesNewExe()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");
        WriteFile(Path.Combine(temp.Path, "NarksharLauncher.exe"), "old launcher");

        var manifest = ManifestJson(("client/NarksharLauncher.exe", "new launcher"));
        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes(manifest),
            ["client/NarksharLauncher.exe"] = Encoding.UTF8.GetBytes("new launcher")
        }));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        var result = await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(File.ReadAllText(Path.Combine(temp.Path, "NarksharLauncher.exe")) == "old launcher", "running launcher should not be overwritten");
        Assert(File.ReadAllText(Path.Combine(temp.Path, "NarksharLauncher.new.exe")) == "new launcher", "new launcher should be staged");
        Assert(result.Message.Contains("NarksharLauncher.new.exe", StringComparison.Ordinal), "staged launcher should be announced");
    }

    private static async Task StaleCleanupPreservesProtectedExecutables()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");
        WriteFile(Path.Combine(temp.Path, "NarksharLauncher.exe"), "launcher");
        WriteFile(Path.Combine(temp.Path, "Data", "old.MPQ"), "old");
        Directory.CreateDirectory(Path.Combine(temp.Path, ".narkshar"));
        await File.WriteAllTextAsync(Path.Combine(temp.Path, ".narkshar", "installed-manifest.json"), ManifestJson(
            ("client/Wow.exe", "wow"),
            ("client/NarksharLauncher.exe", "launcher"),
            ("client/Data/old.MPQ", "old")));

        var manifest = ManifestJson(("client/Data/new.MPQ", "new"));
        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes(manifest),
            ["client/Data/new.MPQ"] = Encoding.UTF8.GetBytes("new")
        }));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(File.Exists(Path.Combine(temp.Path, "Wow.exe")), "Wow.exe should not be stale-deleted");
        Assert(File.Exists(Path.Combine(temp.Path, "NarksharLauncher.exe")), "launcher should not be stale-deleted");
        Assert(!File.Exists(Path.Combine(temp.Path, "Data", "old.MPQ")), "old managed asset should be stale-deleted");
    }

    private static async Task AlreadyStagedLauncherUpdateIsAnnounced()
    {
        using var temp = new TempRoot();
        WriteFile(Path.Combine(temp.Path, "Wow.exe"), "wow");
        WriteFile(Path.Combine(temp.Path, "NarksharLauncher.exe"), "old launcher");
        WriteFile(Path.Combine(temp.Path, "NarksharLauncher.new.exe"), "new launcher");

        var manifest = ManifestJson(("client/NarksharLauncher.exe", "new launcher"));
        using var http = new HttpClient(new FakeHandler(new Dictionary<string, byte[]>
        {
            ["client/manifest.json"] = Encoding.UTF8.GetBytes(manifest)
        }, failOnMissing: true));

        var updater = new NarksharUpdater(temp.Path, http, new Uri("https://assets.test/"));
        var result = await updater.UpdateAsync(new Progress<UpdateProgress>(), CancellationToken.None);

        Assert(result.Message.Contains("NarksharLauncher.new.exe", StringComparison.Ordinal), "already staged launcher should still be announced");
    }

    private static string ManifestJson(params (string Path, string Content)[] files)
    {
        var entries = files.Select(file =>
        {
            var bytes = Encoding.UTF8.GetBytes(file.Content);
            return $$"""    { "path": "{{file.Path}}", "size": {{bytes.Length}}, "sha256": "{{Sha256Hex(bytes)}}" }""";
        });

        return $$"""
        {
          "version": "test",
          "files": [
        {{string.Join(",\n", entries)}}
          ]
        }
        """;
    }

    private static string Sha256Hex(byte[] bytes)
    {
        return Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }

    private static string HashDownloadName(string manifestPath)
    {
        return Sha256Hex(Encoding.UTF8.GetBytes(manifestPath)) + ".download";
    }

    private static void WriteFile(string path, string content)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
    }

    private sealed class FakeHandler(IReadOnlyDictionary<string, byte[]> responses, bool failOnMissing = false) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var key = request.RequestUri?.AbsolutePath.TrimStart('/') ?? "";
            if (!responses.TryGetValue(key, out var body))
            {
                if (failOnMissing)
                {
                    throw new InvalidOperationException($"Unexpected download: {key}");
                }

                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new ByteArrayContent(body)
            });
        }
    }

    private sealed class TempRoot : IDisposable
    {
        public TempRoot()
        {
            Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "NarksharLauncher.Tests", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path);
        }

        public string Path { get; }

        public void Dispose()
        {
            Directory.Delete(Path, recursive: true);
        }
    }
}
