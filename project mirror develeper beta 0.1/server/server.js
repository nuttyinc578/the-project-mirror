"use strict";

const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const { execFile } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const CONFIG_PATH = process.env.PROJECT_MIRROR_CONFIG || path.join(ROOT, "config", "project_mirror.json");

function defaultConfig() {
  return {
    name: "Project Mirror Dev Beta 1",
    version: "1.0.0-beta1",
    server: { host: "127.0.0.1", port: 4971 },
    aiApi: { host: "127.0.0.1", port: 4972 },
    runtime: {
      profile: "balanced",
      ramLimitMb: Number(process.env.PROJECT_MIRROR_RAM_LIMIT_MB || 4096),
      lowRamAlertMb: 1024,
      pollSeconds: 5,
      notificationsEnabled: true,
      msys2Compatible: true
    },
    gui: {
      refreshSeconds: 3,
      taskLimit: 60,
      notifications: true
    }
  };
}

function loadConfig() {
  const defaults = defaultConfig();
  try {
    const parsed = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
    return {
      ...defaults,
      ...parsed,
      server: { ...defaults.server, ...(parsed.server || {}) },
      aiApi: { ...defaults.aiApi, ...(parsed.aiApi || {}) },
      runtime: { ...defaults.runtime, ...(parsed.runtime || {}) },
      gui: { ...defaults.gui, ...(parsed.gui || {}) }
    };
  } catch (error) {
    return defaults;
  }
}

function saveConfig(nextConfig) {
  fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  fs.writeFileSync(CONFIG_PATH, `${JSON.stringify(nextConfig, null, 2)}\n`);
}

let config = loadConfig();

function memorySnapshot() {
  const totalMb = Math.round(os.totalmem() / 1024 / 1024);
  const freeMb = Math.round(os.freemem() / 1024 / 1024);
  const usedMb = totalMb - freeMb;
  const lowRamAlertMb = Number(config.runtime.lowRamAlertMb || 1024);
  const ramLimitMb = Number(config.runtime.ramLimitMb || process.env.PROJECT_MIRROR_RAM_LIMIT_MB || 4096);

  return {
    totalMb,
    freeMb,
    usedMb,
    usedPercent: totalMb > 0 ? Math.round((usedMb / totalMb) * 100) : 0,
    ramLimitMb,
    lowRamAlertMb,
    lowRam: freeMb <= lowRamAlertMb
  };
}

function alertSnapshot() {
  const ram = memorySnapshot();
  const alerts = [];

  if (ram.lowRam) {
    alerts.push({
      id: "low-ram",
      severity: "warning",
      title: "Low RAM",
      message: `${ram.freeMb} MB free is below the ${ram.lowRamAlertMb} MB alert limit.`,
      createdAt: new Date().toISOString()
    });
  }

  return {
    ok: true,
    notificationsEnabled: Boolean(config.runtime.notificationsEnabled),
    ram,
    alerts
  };
}

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
  });
  response.end(`${JSON.stringify(body, null, 2)}\n`);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let raw = "";
    request.on("data", chunk => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        request.destroy(new Error("Request body too large"));
      }
    });
    request.on("end", () => {
      if (!raw.trim()) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(new Error("Invalid JSON body"));
      }
    });
    request.on("error", reject);
  });
}

function execFilePromise(file, args) {
  return new Promise((resolve, reject) => {
    execFile(file, args, { windowsHide: true, maxBuffer: 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        error.stderr = stderr;
        reject(error);
        return;
      }

      resolve(stdout);
    });
  });
}

function parseCsvLine(line) {
  const cells = [];
  let cell = "";
  let quoted = false;

  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    const next = line[index + 1];

    if (char === "\"" && quoted && next === "\"") {
      cell += "\"";
      index += 1;
    } else if (char === "\"") {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      cells.push(cell);
      cell = "";
    } else {
      cell += char;
    }
  }

  cells.push(cell);
  return cells;
}

function parseWindowsTasks(stdout) {
  return stdout
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => {
      const cells = parseCsvLine(line);
      const memoryKb = Number(String(cells[4] || "0").replace(/[^\d]/g, ""));
      return {
        name: cells[0] || "unknown",
        pid: Number(cells[1] || 0),
        memoryMb: Math.round(memoryKb / 1024),
        cpuPercent: null,
        command: cells[0] || ""
      };
    })
    .filter(task => task.pid > 0);
}

function parsePosixTasks(stdout) {
  return stdout
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => {
      const match = line.match(/^(\d+)\s+(.+?)\s+(\d+)\s+([\d.]+)$/);
      if (!match) {
        return null;
      }

      return {
        pid: Number(match[1]),
        name: match[2],
        memoryMb: Math.round(Number(match[3]) / 1024),
        cpuPercent: Number(match[4]),
        command: match[2]
      };
    })
    .filter(Boolean);
}

async function listTasks(limit) {
  const maxTasks = Math.max(1, Math.min(Number(limit || config.gui.taskLimit || 60), 200));
  const tasks = process.platform === "win32"
    ? parseWindowsTasks(await execFilePromise("tasklist", ["/FO", "CSV", "/NH"]))
    : parsePosixTasks(await execFilePromise("ps", ["-axo", "pid=,comm=,rss=,pcpu="]));

  return tasks
    .sort((left, right) => right.memoryMb - left.memoryMb)
    .slice(0, maxTasks);
}

function bridgeInfo() {
  return {
    ok: true,
    root: ROOT,
    configPath: CONFIG_PATH,
    endpoints: {
      node: `http://${config.server.host}:${config.server.port}`,
      pythonAi: `http://${config.aiApi.host}:${config.aiApi.port}`
    },
    commands: {
      rubyLauncher: "ruby launch_project_mirror.rb",
      dotnetMenu: "dotnet run --project src/dotnet/ProjectMirrorLauncher/ProjectMirrorLauncher.csproj",
      pythonApi: "python -m project_mirror_ai.server",
      nodeServer: "node server/server.js",
      swiftGui: "swift run --package-path src/swift/ProjectMirrorGUI ProjectMirrorGUI"
    }
  };
}

function updateRuntime(body) {
  const runtime = { ...config.runtime };

  if (body.profile) {
    runtime.profile = String(body.profile);
  }

  if (Number.isFinite(Number(body.ramLimitMb))) {
    runtime.ramLimitMb = Math.max(256, Math.round(Number(body.ramLimitMb)));
  }

  if (Number.isFinite(Number(body.lowRamAlertMb))) {
    runtime.lowRamAlertMb = Math.max(128, Math.round(Number(body.lowRamAlertMb)));
  }

  if (typeof body.notificationsEnabled === "boolean") {
    runtime.notificationsEnabled = body.notificationsEnabled;
  }

  config.runtime = runtime;
  saveConfig(config);
  return runtime;
}

function fallbackOptimize(payload) {
  const memory = memorySnapshot();
  const gameplay = payload.gameplay || {};
  const video = payload.video || {};
  const currentFps = Number(gameplay.currentFps || 0);
  const targetFps = Number(gameplay.targetFps || config.profiles?.[config.runtime.profile]?.targetFps || 60);
  const latencyMs = Number(gameplay.latencyMs || 0);
  const needsPerformance = memory.lowRam || (currentFps > 0 && currentFps < targetFps * 0.9) || latencyMs > 55;
  const profile = needsPerformance ? "performance" : config.runtime.profile || "balanced";
  const upscale = profile !== "performance" && Number(video.width || 0) < 2560;

  return {
    project: config.name,
    version: config.version,
    source: "node-fallback",
    profile,
    summary: [
      memory.lowRam ? "Low RAM detected, using performance-safe settings." : "RAM is inside the configured safe range.",
      upscale ? "Video enhancement plan includes denoise, sharpen, color lift, and smart upscale." : "Video enhancement plan favors stable frame pacing over upscaling.",
      needsPerformance ? "Gameplay plan prioritizes latency and frame stability." : "Gameplay plan keeps a balanced quality/performance target."
    ],
    videoEnhancement: {
      enabled: true,
      upscale,
      filterChain: upscale
        ? "hqdn3d=1.5:1.5:6:6,unsharp=5:5:0.65:3:3:0.25,eq=contrast=1.04:saturation=1.08,scale=2560:-2:flags=lanczos"
        : "hqdn3d=1.2:1.2:4:4,unsharp=3:3:0.4,eq=contrast=1.02:saturation=1.04",
      ffmpegExample: "ffmpeg -i input.mp4 -vf \"FILTER_CHAIN\" -c:v libx264 -preset slow -crf 20 -c:a copy output_mirror.mp4"
    },
    gameplayOptimization: {
      targetFps,
      recommendations: needsPerformance
        ? ["Use performance profile", "Reduce shadows and reflections first", "Cap FPS close to monitor refresh", "Disable background capture while gaming"]
        : ["Use balanced profile", "Keep frame cap stable", "Use adaptive sync when available"]
    },
    osOptimization: {
      ram: memory,
      recommendations: memory.lowRam
        ? ["Close heavy background apps", "Lower video enhancement quality", "Restart Project Mirror services after freeing RAM"]
        : ["Keep Game Mode enabled", "Use high performance power mode while plugged in", "Keep GPU drivers current"]
    }
  };
}

async function callPythonAi(payload) {
  const url = `http://${config.aiApi.host}:${config.aiApi.port}/optimize`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`Python AI API returned ${response.status}`);
    }

    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

async function handleRequest(request, response) {
  const url = new URL(request.url, `http://${request.headers.host || "127.0.0.1"}`);

  if (request.method === "OPTIONS") {
    sendJson(response, 204, {});
    return;
  }

  if (request.method === "GET" && url.pathname === "/health") {
    sendJson(response, 200, {
      ok: true,
      project: config.name,
      version: config.version,
      service: "node-control-server",
      node: process.version,
      configPath: CONFIG_PATH,
      ram: memorySnapshot()
    });
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/config") {
    config = loadConfig();
    sendJson(response, 200, config);
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/ram") {
    sendJson(response, 200, memorySnapshot());
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/alerts") {
    sendJson(response, 200, alertSnapshot());
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/bridge") {
    sendJson(response, 200, bridgeInfo());
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/tasks") {
    try {
      const tasks = await listTasks(url.searchParams.get("limit"));
      sendJson(response, 200, { ok: true, tasks, count: tasks.length, ram: memorySnapshot() });
    } catch (error) {
      sendJson(response, 200, { ok: false, tasks: [], error: error.message, ram: memorySnapshot() });
    }
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/tasks/end") {
    const body = await readBody(request);
    const pid = Number(body.pid);
    if (!Number.isInteger(pid) || pid <= 0) {
      sendJson(response, 400, { ok: false, error: "Valid pid is required" });
      return;
    }

    if (pid === process.pid) {
      sendJson(response, 400, { ok: false, error: "Refusing to stop the Project Mirror server process" });
      return;
    }

    if (body.confirm !== "end-task") {
      sendJson(response, 400, { ok: false, error: "confirm must be end-task" });
      return;
    }

    try {
      process.kill(pid);
      sendJson(response, 200, { ok: true, pid });
    } catch (error) {
      sendJson(response, 500, { ok: false, error: error.message, pid });
    }
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/runtime") {
    const body = await readBody(request);
    const runtime = updateRuntime(body);
    sendJson(response, 200, { ok: true, runtime, ram: memorySnapshot(), alerts: alertSnapshot().alerts });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/profile") {
    const body = await readBody(request);
    const nextProfile = String(body.profile || "").trim();
    if (!nextProfile) {
      sendJson(response, 400, { ok: false, error: "profile is required" });
      return;
    }

    config.runtime.profile = nextProfile;
    saveConfig(config);
    sendJson(response, 200, { ok: true, profile: nextProfile });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/optimize") {
    const body = await readBody(request);
    const ram = memorySnapshot();
    const payload = {
      ...body,
      project: config.name,
      mode: body.mode || "auto",
      system: {
        ...(body.system || {}),
        totalRamMb: ram.totalMb,
        freeRamMb: ram.freeMb,
        ramLimitMb: ram.ramLimitMb,
        lowRamAlertMb: ram.lowRamAlertMb,
        nodeProfile: config.runtime.profile
      }
    };

    try {
      const aiPlan = await callPythonAi(payload);
      sendJson(response, 200, { ...aiPlan, source: aiPlan.source || "python-ai-api", ram });
    } catch (error) {
      sendJson(response, 200, {
        ...fallbackOptimize(payload),
        pythonApiWarning: error.message
      });
    }
    return;
  }

  sendJson(response, 404, { ok: false, error: "Not found" });
}

const server = http.createServer((request, response) => {
  handleRequest(request, response).catch(error => {
    sendJson(response, 500, { ok: false, error: error.message });
  });
});

server.listen(config.server.port, config.server.host, () => {
  console.log(`${config.name} server listening on http://${config.server.host}:${config.server.port}`);
  console.log(`Config: ${CONFIG_PATH}`);
});
