param(
  [string]$Python = "python",
  [string]$OutputDir = "dist/python-ai"
)

$ErrorActionPreference = "Stop"

& $Python -m PyInstaller --onefile `
  --name project-mirror-ai `
  --paths src/python `
  --distpath $OutputDir `
  src/python/project_mirror_ai/cli.py

Write-Host "Built Python AI executable in $OutputDir"
