# Project Mirror Dev Beta 1 Architecture

## Components

`launch_project_mirror.rb` is the main launcher. It is MSYS2-friendly Ruby and can start the Node bridge server, the Python AI API, the .NET menu, and the Swift GUI.

`server/server.js` is the local bridge server. It exposes health, RAM, alerts, task-manager data, config, runtime settings, profile, and optimization endpoints. When the Python AI API is online, Node forwards optimization requests to it. If Python is offline, Node returns a safe fallback profile.

`src/python/project_mirror_ai` contains the AI optimization logic. The first beta uses a deterministic optimizer so it can run offline and without third-party dependencies. A future model API can be added behind the same `/optimize` endpoint.

`src/dotnet/ProjectMirrorLauncher` is the RAM/menu component. It edits the shared config, checks available RAM, warns on low RAM, can ask the Node server for an optimization plan, and can launch the Swift GUI.

`src/swift/ProjectMirrorGUI` is the UI/UX GUI layer. It contains Swift core models, the Node bridge client, memory formatting helpers, notification handling, and SwiftUI views for dashboard, task manager, RAM limits, optimizer, and runtime bridge status.

`core/project_mirror_core.json` is the shared runtime contract for Ruby, Node.js, Python, .NET, and Swift.

## Launch Flow

1. Ruby reads `config/project_mirror.json`.
2. Ruby starts Node.js with the shared config path.
3. Ruby starts the Python AI API when Python is available.
4. Ruby optionally opens the .NET menu or Swift GUI.
5. Swift talks to Node for live RAM, tasks, alerts, runtime saves, and optimization plans.
6. Node receives optimization requests and asks Python for a plan.
7. .NET remains available as a console RAM control and alert fallback.

## API

Node control server:

- `GET /health`
- `GET /api/config`
- `GET /api/ram`
- `GET /api/alerts`
- `GET /api/tasks?limit=60`
- `GET /api/bridge`
- `POST /api/runtime`
- `POST /api/profile`
- `POST /api/tasks/end`
- `POST /api/optimize`

Python AI API:

- `GET /health`
- `POST /optimize`

## RAM Limits

The RAM limit is a Project Mirror soft limit. It is saved to config and passed through `PROJECT_MIRROR_RAM_LIMIT_MB`. Node, Python, Swift, .NET, and future launchers can use it to reject heavy jobs, lower quality presets, or warn before memory pressure becomes unstable.

## Task Manager

The task manager is exposed through Node so the GUI does not need platform-specific process code. Task ending requires `POST /api/tasks/end` with a numeric `pid` and `confirm: "end-task"`.
