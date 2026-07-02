# Project Mirror Dev Beta 1

Project Mirror Dev Beta 1 is a local AI-style optimizer scaffold for:

- video quality enhancement plans
- gameplay performance profiles
- OS and RAM optimization alerts
- a Ruby/MSYS2 launcher that starts the system
- a Node.js control server and GUI bridge
- a Python AI API and CLI
- a .NET launcher/menu for RAM limits and low-RAM alerts
- a Swift UI/UX GUI window for dashboard, task manager, RAM limits, and notifications

## Quick Start

Start the full stack with Ruby and open the Swift GUI:

```powershell
ruby launch_project_mirror.rb --gui
```

Start the full stack with the .NET RAM menu:

```powershell
ruby launch_project_mirror.rb --menu
```

Start only the Node.js bridge server:

```powershell
node server/server.js
```

Run the Swift GUI package directly:

```powershell
swift run --package-path src/swift/ProjectMirrorGUI ProjectMirrorGUI
```

Start the Python AI API:

```powershell
$env:PYTHONPATH="src/python"
python -m project_mirror_ai.server
```

Run the .NET menu:

```powershell
dotnet run --project src/dotnet/ProjectMirrorLauncher/ProjectMirrorLauncher.csproj
```

## Main Ports

- Node control server and GUI bridge: `http://127.0.0.1:4971`
- Python AI API: `http://127.0.0.1:4972`

## GUI

The Swift package lives in `src/swift/ProjectMirrorGUI`.

- On macOS, it builds as a SwiftUI window.
- On Windows or other platforms without SwiftUI, the package builds the shared Swift core and a console fallback.
- The GUI talks to Node through `/api/ram`, `/api/tasks`, `/api/runtime`, `/api/alerts`, `/api/optimize`, and `/api/bridge`.

## Build EXE Targets

Python AI CLI EXE:

```powershell
scripts/build_python_exe.ps1
```

.NET launcher/menu EXE:

```powershell
scripts/publish_dotnet_launcher.ps1
```

Swift GUI package:

```powershell
scripts/build_swift_gui.ps1
```

## Notes

This beta does not install drivers, change Windows registry settings, or force game settings globally. It produces safe optimization profiles, RAM warnings, video enhancement command plans, task-manager data, and launch-time environment limits that Project Mirror services can obey.
