param(
  [string]$Swift = "swift",
  [string]$Configuration = "debug"
)

$ErrorActionPreference = "Stop"

& $Swift build --package-path src/swift/ProjectMirrorGUI -c $Configuration
Write-Host "Built Project Mirror Swift GUI package."
