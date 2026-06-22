# Narkshar

Public client assets and launcher source for the Narkshar WoW 3.3.5a client bundle.

## Use

Place `NarksharLauncher.exe` in the same folder as `Wow.exe`, run it, let it update the managed client files, then press Play.

The launcher installs the files listed in `client/manifest.json` from the Narkshar S3 bucket into the WoW client folder. It checks local file size and SHA-256 first, and only downloads missing or mismatched files.

Download the latest `NarksharLauncher.exe` from this repo's GitHub Releases page.

## Managed payload

- `client/Data/`
- `client/Interface/AddOns/`
- optional local upload payloads such as `client/Wow.exe` and `client/NarksharLauncher.exe`

The launcher records installed files in `.narkshar/installed-manifest.json` and only removes files it previously managed.
It never stale-deletes `Wow.exe` or launcher executables. If `client/NarksharLauncher.exe` changes, the running launcher stages it as `NarksharLauncher.new.exe`; close the old launcher and run the staged file to update.

## S3

The public bucket policy should allow anonymous `s3:GetObject` only. Do not allow anonymous `s3:ListBucket` or any anonymous writes.

After configuring AWS CLI credentials for the `narkshar-publisher` profile:

```bash
scripts/setup-s3-bucket.sh
scripts/upload-s3.sh
```

Defaults:

- region: `us-east-1`
- bucket: `narkshar-client-assets-<aws-account-id>`
- manifest URL: `https://<bucket>.s3.us-east-1.amazonaws.com/client/manifest.json`

Use `AWS_PROFILE`, `AWS_REGION`, `AWS_ACCOUNT_ID`, or `S3_BUCKET` to override script defaults. For local launcher testing against a non-default bucket, set `NARKSHAR_ASSET_BASE_URL` to the bucket base URL.

## Build

Requires the official .NET SDK with Windows targeting support.

```bash
dotnet publish launcher/src/NarksharLauncher/NarksharLauncher.csproj \
  -c Release -r win-x64 --self-contained true \
  -p:NarksharAssetBaseUrl=https://<bucket>.s3.us-east-1.amazonaws.com/ \
  -p:PublishSingleFile=true -p:PublishTrimmed=false
```
