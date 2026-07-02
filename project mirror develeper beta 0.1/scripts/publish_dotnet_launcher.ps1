param(
  [string]$Configuration = "Release",
  [string]$Runtime = "win-x64",
  [string]$OutputDir = "dist/dotnet-launcher"
)

$ErrorActionPreference = "Stop"

dotnet publish src/dotnet/ProjectMirrorLauncher/ProjectMirrorLauncher.csproj `
  -c $Configuration `
  -r $Runtime `
  --self-contained false `
  /p:PublishSingleFile=true `
  -o $OutputDir

Write-Host "Published .NET launcher/menu executable in $OutputDir"
