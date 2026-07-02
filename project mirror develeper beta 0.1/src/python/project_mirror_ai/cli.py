"""CLI for Project Mirror Dev Beta 1 optimization plans."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

from .optimizer import build_optimization_plan


def read_payload(path: str | None) -> Dict[str, Any]:
    if not path:
        return {
            "mode": "auto",
            "video": {"input": "input.mp4", "width": 1920, "height": 1080, "fps": 60},
            "gameplay": {"currentFps": 58, "targetFps": 60, "latencyMs": 42},
            "system": {"totalRamMb": 16384, "freeRamMb": 4096, "ramLimitMb": 4096, "lowRamAlertMb": 1024},
        }

    return json.loads(Path(path).read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a Project Mirror optimization plan.")
    parser.add_argument("--input", help="JSON telemetry input file")
    parser.add_argument("--output", help="Write plan to JSON file")
    parser.add_argument("--mode", help="Override optimization mode")
    parser.add_argument("--compact", action="store_true", help="Write compact JSON")
    args = parser.parse_args()

    payload = read_payload(args.input)
    if args.mode:
        payload["mode"] = args.mode

    plan = build_optimization_plan(payload)
    indent = None if args.compact else 2
    text = json.dumps(plan, indent=indent)

    if args.output:
        Path(args.output).write_text(f"{text}\n", encoding="utf-8")
    else:
        sys.stdout.write(f"{text}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
