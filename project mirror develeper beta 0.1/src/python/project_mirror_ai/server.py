"""HTTP API for Project Mirror Dev Beta 1 AI optimization."""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Dict

from .optimizer import PROJECT_NAME, VERSION, build_optimization_plan


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONFIG = ROOT / "config" / "project_mirror.json"


def load_config(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        return {}
    except json.JSONDecodeError:
        return {}


def write_json(handler: BaseHTTPRequestHandler, status: int, body: Dict[str, Any]) -> None:
    data = json.dumps(body, indent=2).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


class ProjectMirrorHandler(BaseHTTPRequestHandler):
    config_path = DEFAULT_CONFIG

    def do_OPTIONS(self) -> None:
        write_json(self, 204, {})

    def do_GET(self) -> None:
        if self.path == "/health":
            write_json(
                self,
                200,
                {
                    "ok": True,
                    "project": PROJECT_NAME,
                    "version": VERSION,
                    "service": "python-ai-api",
                    "configPath": str(self.config_path),
                },
            )
            return

        write_json(self, 404, {"ok": False, "error": "Not found"})

    def do_POST(self) -> None:
        if self.path != "/optimize":
            write_json(self, 404, {"ok": False, "error": "Not found"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(content_length).decode("utf-8") if content_length else "{}"
            payload = json.loads(raw or "{}")
        except json.JSONDecodeError:
            write_json(self, 400, {"ok": False, "error": "Invalid JSON body"})
            return

        config = load_config(self.config_path)
        runtime = dict(config.get("runtime") or {})
        system = dict(payload.get("system") or {})
        system.setdefault("profile", runtime.get("profile", "balanced"))
        system.setdefault("ramLimitMb", runtime.get("ramLimitMb", 4096))
        system.setdefault("lowRamAlertMb", runtime.get("lowRamAlertMb", 1024))
        payload["system"] = system
        payload.setdefault("project", config.get("name", PROJECT_NAME))

        write_json(self, 200, build_optimization_plan(payload))

    def log_message(self, format: str, *args: Any) -> None:
        print(f"[project-mirror-ai] {self.address_string()} - {format % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Project Mirror Dev Beta 1 Python AI API")
    parser.add_argument("--host", default=None)
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--config", default=str(DEFAULT_CONFIG))
    args = parser.parse_args()

    config_path = Path(args.config).resolve()
    config = load_config(config_path)
    ai_api = dict(config.get("aiApi") or {})
    host = args.host or ai_api.get("host") or "127.0.0.1"
    port = int(args.port or ai_api.get("port") or 4972)

    ProjectMirrorHandler.config_path = config_path
    server = HTTPServer((host, port), ProjectMirrorHandler)
    print(f"{PROJECT_NAME} AI API listening on http://{host}:{port}")
    print(f"Config: {config_path}")
    server.serve_forever()


if __name__ == "__main__":
    main()
