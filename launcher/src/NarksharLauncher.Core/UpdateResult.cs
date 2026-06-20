namespace NarksharLauncher;

public sealed class UpdateResult
{
    public bool Updated { get; init; }
    public bool CanPlay { get; init; }
    public string Message { get; init; } = "";
}
