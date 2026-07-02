"""Offline AI-style optimization engine for Project Mirror Dev Beta 1."""

from __future__ import annotations

from typing import Any, Dict, List


PROJECT_NAME = "Project Mirror Dev Beta 1"
VERSION = "1.0.0-beta1"


def _number(value: Any, fallback: float = 0.0) -> float:
    try:
        if value is None:
            return fallback
        return float(value)
    except (TypeError, ValueError):
        return fallback


def _pick_profile(system: Dict[str, Any], gameplay: Dict[str, Any]) -> str:
    free_ram = _number(system.get("freeRamMb"), _number(system.get("free_ram_mb"), 4096))
    low_ram = _number(system.get("lowRamAlertMb"), _number(system.get("low_ram_alert_mb"), 1024))
    current_fps = _number(gameplay.get("currentFps"), _number(gameplay.get("current_fps"), 0))
    target_fps = _number(gameplay.get("targetFps"), _number(gameplay.get("target_fps"), 60))
    latency_ms = _number(gameplay.get("latencyMs"), _number(gameplay.get("latency_ms"), 0))
    cpu_load = _number(system.get("cpuLoadPercent"), _number(system.get("cpu_load_percent"), 0))

    if free_ram <= low_ram or cpu_load >= 88:
        return "performance"
    if current_fps and current_fps < target_fps * 0.9:
        return "performance"
    if latency_ms >= 55:
        return "performance"
    if current_fps and current_fps >= target_fps * 1.2 and free_ram > low_ram * 2:
        return "quality"
    return str(system.get("nodeProfile") or system.get("profile") or "balanced")


def _video_plan(video: Dict[str, Any], profile: str) -> Dict[str, Any]:
    width = int(_number(video.get("width"), 1920))
    height = int(_number(video.get("height"), 1080))
    fps = int(_number(video.get("fps"), 60))
    input_file = str(video.get("input") or "input.mp4")
    output_file = str(video.get("output") or "output_mirror_enhanced.mp4")

    filters: List[str] = []
    crf = 20
    preset = "slow"

    if profile == "performance":
        filters.extend(["hqdn3d=1.2:1.2:4:4", "unsharp=3:3:0.35", "eq=contrast=1.02:saturation=1.03"])
        crf = 23
        preset = "medium"
    elif profile == "quality":
        filters.extend(["hqdn3d=1.8:1.8:7:7", "unsharp=5:5:0.75:3:3:0.3", "eq=contrast=1.05:saturation=1.1"])
        crf = 18
    else:
        filters.extend(["hqdn3d=1.5:1.5:6:6", "unsharp=5:5:0.55:3:3:0.2", "eq=contrast=1.04:saturation=1.08"])
        crf = 20

    upscale = profile != "performance" and width < 2560
    if upscale:
        filters.append("scale=2560:-2:flags=lanczos")

    if fps < 60 and profile != "performance":
        filters.append("fps=60")

    filter_chain = ",".join(filters)
    ffmpeg_command = (
        f'ffmpeg -i "{input_file}" -vf "{filter_chain}" '
        f'-c:v libx264 -preset {preset} -crf {crf} -c:a copy "{output_file}"'
    )

    return {
        "enabled": True,
        "profile": profile,
        "input": input_file,
        "output": output_file,
        "upscale": upscale,
        "targetWidth": 2560 if upscale else width,
        "targetFps": 60 if fps < 60 and profile != "performance" else fps,
        "filterChain": filter_chain,
        "ffmpegCommand": ffmpeg_command,
        "notes": [
            "Denoise is kept moderate to avoid waxy textures.",
            "Sharpening runs after denoise for clearer edges.",
            "Upscale is disabled in performance mode to protect frame pacing."
        ],
    }


def _gameplay_plan(gameplay: Dict[str, Any], profile: str) -> Dict[str, Any]:
    target_fps = int(_number(gameplay.get("targetFps"), _number(gameplay.get("target_fps"), 60)))
    current_fps = _number(gameplay.get("currentFps"), _number(gameplay.get("current_fps"), 0))
    latency_ms = _number(gameplay.get("latencyMs"), _number(gameplay.get("latency_ms"), 0))

    recommendations = [
        "Set a stable FPS cap near the monitor refresh rate.",
        "Keep GPU drivers updated before tuning individual games.",
    ]

    if profile == "performance":
        recommendations.extend(
            [
                "Lower shadows, volumetric fog, screen-space reflections, and motion blur first.",
                "Disable background recording while playing.",
                "Prefer exclusive fullscreen when the game supports it cleanly.",
                "Use low latency mode in the GPU control panel when available.",
            ]
        )
    elif profile == "quality":
        recommendations.extend(
            [
                "Increase texture filtering and anti-aliasing before raising render scale.",
                "Keep frame cap slightly under max refresh for smoother pacing.",
            ]
        )
    else:
        recommendations.extend(
            [
                "Use balanced preset and adjust only the heaviest settings per game.",
                "Keep adaptive sync enabled when supported.",
            ]
        )

    return {
        "profile": profile,
        "currentFps": current_fps,
        "targetFps": target_fps,
        "latencyMs": latency_ms,
        "recommendations": recommendations,
    }


def _os_plan(system: Dict[str, Any], profile: str) -> Dict[str, Any]:
    total_ram = int(_number(system.get("totalRamMb"), _number(system.get("total_ram_mb"), 0)))
    free_ram = int(_number(system.get("freeRamMb"), _number(system.get("free_ram_mb"), 0)))
    ram_limit = int(_number(system.get("ramLimitMb"), _number(system.get("ram_limit_mb"), 4096)))
    low_ram = int(_number(system.get("lowRamAlertMb"), _number(system.get("low_ram_alert_mb"), 1024)))
    ram_pressure = total_ram > 0 and free_ram <= low_ram

    recommendations = [
        "Enable Windows Game Mode for supported titles.",
        "Use a high performance power plan while plugged in.",
        "Pause heavy sync, backup, and capture tools while gaming or enhancing video.",
    ]

    if ram_pressure:
        recommendations.insert(0, "Free RAM before running high-quality video enhancement.")
        recommendations.insert(1, "Use the performance profile until available RAM is above the alert threshold.")

    return {
        "profile": profile,
        "ram": {
            "totalMb": total_ram,
            "freeMb": free_ram,
            "ramLimitMb": ram_limit,
            "lowRamAlertMb": low_ram,
            "lowRam": bool(ram_pressure),
        },
        "recommendations": recommendations,
    }


def build_optimization_plan(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Build a deterministic optimization plan from telemetry payload data."""

    video = dict(payload.get("video") or {})
    gameplay = dict(payload.get("gameplay") or {})
    system = dict(payload.get("system") or {})
    mode = str(payload.get("mode") or "auto")
    profile = _pick_profile(system, gameplay)

    video_plan = _video_plan(video, profile)
    gameplay_plan = _gameplay_plan(gameplay, profile)
    os_plan = _os_plan(system, profile)

    summary = [
        f"Selected {profile} profile for mode {mode}.",
        "Video plan is ready for FFmpeg-based enhancement.",
        "Gameplay plan focuses on stable frame pacing before visual extras.",
    ]

    if os_plan["ram"]["lowRam"]:
        summary.insert(1, "Low RAM detected, so heavy enhancement is reduced.")

    return {
        "ok": True,
        "project": str(payload.get("project") or PROJECT_NAME),
        "version": VERSION,
        "source": "python-ai-api",
        "mode": mode,
        "profile": profile,
        "summary": summary,
        "videoEnhancement": video_plan,
        "gameplayOptimization": gameplay_plan,
        "osOptimization": os_plan,
        "safety": {
            "changesSystemSettings": False,
            "requiresAdmin": False,
            "notes": [
                "This beta returns plans and safe launch settings.",
                "It does not edit registry, drivers, or game files automatically.",
            ],
        },
    }
