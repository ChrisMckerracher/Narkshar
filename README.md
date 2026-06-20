# Narkshar

Public client assets and launcher source for the Narkshar WoW 3.3.5a client bundle.

## Use

Place `NarksharLauncher.exe` in the same folder as `Wow.exe`, run it, let it update the managed client files, then press Play.

The launcher installs the files listed in `manifest.json` from `client/` into the WoW client folder.

## Managed payload

- `client/Data/`
- `client/Interface/AddOns/`

The launcher records installed files in `.narkshar/installed-manifest.json` and only removes files it previously managed.

## Build

Requires the official .NET SDK with Windows targeting support.

```bash
dotnet publish launcher/src/NarksharLauncher/NarksharLauncher.csproj \
  -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:PublishTrimmed=false
```
