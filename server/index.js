import express from "express";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { generateCode, newSessionToken, pbkdf2Hash, pbkdf2Verify } from "./auth.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(express.json({ limit: "1mb" }));
app.use(requireAuth);

const ROOT = path.resolve(__dirname, "..");
const WEB_DIR = path.join(ROOT, "web");
const SH_DIR = path.join(ROOT, "sh");
const STATE_DIR = path.join(SH_DIR, "state");
const RUN_DIR = path.join(STATE_DIR, "runs");
fs.mkdirSync(RUN_DIR, { recursive: true });

// --- Auth (dashboard access code) ---
const AUTH_PATH = path.join(STATE_DIR, "auth.json");
const sessions = new Map(); // token -> { createdAt }

function readAuth() {
  try {
    if (!fs.existsSync(AUTH_PATH)) return null;
    return JSON.parse(fs.readFileSync(AUTH_PATH, "utf8"));
  } catch {
    return null;
  }
}

function hasAuth() {
  const a = readAuth();
  return !!(a && a.hash && a.salt);
}

function writeAuth(record) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(AUTH_PATH, JSON.stringify(record, null, 2), "utf8");
}

function parseCookies(req) {
  const header = req.headers.cookie;
  if (!header) return {};
  const out = {};
  for (const part of header.split(";")) {
    const [k, ...rest] = part.trim().split("=");
    out[k] = decodeURIComponent(rest.join("="));
  }
  return out;
}

function requireAuth(req, res, next) {
  // Allow auth endpoints and static assets
  if (req.path.startsWith("/api/auth/")) return next();
  if (
    req.path.startsWith("/assets/") ||
    req.path.startsWith("/favicon") ||
    req.path.startsWith("/apple-touch") ||
    req.path.startsWith("/icon-")
  )
    return next();

  // Root can always load; it will show the auth screen when needed.
  if (req.path === "/" || req.path === "/index.html") return next();

  if (!hasAuth()) {
    // Not bootstrapped yet; allow UI to bootstrap.
    return next();
  }

  const cookies = parseCookies(req);
  const token = cookies.autoclaw_session;
  if (token && sessions.has(token)) return next();

  // If this is a page navigation (HTML) and user is not authed,
  // redirect to root so the entry point is always consistent.
  const accept = String(req.headers.accept || "");
  const wantsHtml = req.method === "GET" && accept.includes("text/html");
  const isApi = req.path.startsWith("/api/");
  if (wantsHtml && !isApi) {
    return res.redirect(302, "/");
  }

  // For API calls, return JSON 401.
  res.status(401).json({ ok: false, error: "AUTH_REQUIRED" });
}

/**
 * Very small job runner:
 * - runs sh/tasks/<task>.sh
 * - captures stdout/stderr
 * - streams via SSE
 *
 * Security default:
 * - binds to 127.0.0.1 only unless AUTOCLAW_BIND=0.0.0.0 is set.
 */

let current = null; // { id, task, startedAt, proc, logPath, status }

function nowIso() {
  return new Date().toISOString();
}

async function getPublicIp() {
  // Best-effort. Avoid adding deps.
  const urls = [
    "https://api.ipify.org",
    "https://ifconfig.me",
    "https://checkip.amazonaws.com",
  ];

  for (const url of urls) {
    try {
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 2500);
      const res = await fetch(url, { signal: ctrl.signal });
      clearTimeout(t);
      const ip = (await res.text()).trim();
      if (/^\d+\.\d+\.\d+\.\d+$/.test(ip)) return ip;
    } catch {
      // ignore
    }
  }
  return null;
}

const TASK_ALIASES = {
  // Back-compat (old numeric ids -> new semantic ids)
  "00_doctor": "doctor",
  "10_prereqs": "prereqs",
  "10a_swap": "swap",
  "11_node_pnpm": "node_pnpm",
  "20a_install_openclaw_cli": "install_openclaw_cli",
  "21_write_config": "write_config",
  "22_start_gateway": "start_gateway",
  "24_provider_setup": "provider_setup",
  "25_channels_setup": "channels_setup",
  "23_start_node": "start_node",
};

function normalizeTaskId(task) {
  return TASK_ALIASES[task] || task;
}

function runTask(task, env = {}) {
  if (current && current.status === "running") {
    throw new Error("A task is already running");
  }

  const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const norm = normalizeTaskId(task);
  const scriptPath = path.join(SH_DIR, "tasks", `${norm}.sh`);
  if (!fs.existsSync(scriptPath)) {
    throw new Error(`Task script not found: ${task}`);
  }

  const logPath = path.join(RUN_DIR, `${id}.log`);
  const logStream = fs.createWriteStream(logPath, { flags: "a" });

  const proc = spawn("bash", [scriptPath], {
    cwd: ROOT,
    env: {
      ...process.env,
      AUTOCLAW_ROOT: ROOT,
      AUTOCLAW_STATE: STATE_DIR,
      ...env,
    },
  });

  current = {
    id,
    task,
    startedAt: nowIso(),
    status: "running",
    logPath,
    pid: proc.pid,
  };

  const write = (chunk) => {
    const s = chunk.toString();
    logStream.write(s);
  };

  proc.stdout.on("data", write);
  proc.stderr.on("data", write);

  proc.on("close", (code) => {
    current.status = code === 0 ? "ok" : "error";
    current.exitCode = code;
    current.endedAt = nowIso();
    logStream.end(`\n[autoclaw] task finished: code=${code}\n`);

    // Persist per-task result for wizard progress (best-effort)
    try {
      const statusPath = path.join(STATE_DIR, "task_status.json");
      const prev = fs.existsSync(statusPath) ? JSON.parse(fs.readFileSync(statusPath, "utf8")) : {};
      prev[task] = {
        status: current.status,
        exitCode: code,
        lastRunId: id,
        startedAt: current.startedAt,
        endedAt: current.endedAt,
      };
      fs.writeFileSync(statusPath, JSON.stringify(prev, null, 2), "utf8");
    } catch {
      // ignore
    }
  });

  logStream.write(`[autoclaw] task started: ${norm} (req=${task}) id=${id} at=${current.startedAt}\n`);
  current.task = norm;
  return current;
}

function cmdExists(cmd) {
  try {
    const which = spawn("bash", ["-lc", `command -v ${cmd}`]);
    return new Promise((resolve) => {
      let out = "";
      which.stdout.on("data", (d) => (out += d.toString()));
      which.on("close", (code) => resolve(code === 0 && out.trim().length > 0));
    });
  } catch {
    return Promise.resolve(false);
  }
}

async function detectEnv() {
  const read = (p) => {
    try { return fs.readFileSync(p, "utf8"); } catch { return ""; }
  };
  const osRelease = read("/etc/os-release");
  const procVer = read("/proc/version");
  const uname = process.platform;
  const isWsl = /microsoft/i.test(procVer);
  const hasSystemd = fs.existsSync("/run/systemd/system");
  return { osRelease: osRelease.split("\n").slice(0, 20).join("\n"), isWsl, hasSystemd, platform: uname };
}

async function getMemSwap() {
  try {
    const txt = fs.readFileSync("/proc/meminfo", "utf8");
    const memTotalKb = Number((txt.match(/^MemTotal:\s+(\d+)\s+kB/m) || [])[1] || 0);
    const swapTotalKb = Number((txt.match(/^SwapTotal:\s+(\d+)\s+kB/m) || [])[1] || 0);
    return {
      memTotalMb: memTotalKb ? Math.round(memTotalKb / 1024) : null,
      swapTotalMb: swapTotalKb ? Math.round(swapTotalKb / 1024) : 0,
    };
  } catch {
    return { memTotalMb: null, swapTotalMb: null };
  }
}

// Prevent stale UI from being served by aggressive caches.
app.use((req, res, next) => {
  if (req.path === "/" || req.path === "/index.html") {
    res.setHeader("Cache-Control", "no-store");
  }
  next();
});

app.use(
  "/",
  express.static(WEB_DIR, {
    etag: false,
    setHeaders(res, filePath) {
      if (filePath.endsWith("index.html")) {
        res.setHeader("Cache-Control", "no-store");
      }
    },
  })
);

// Auth API
app.get("/api/auth/status", (req, res) => {
  const a = readAuth();
  const cookies = parseCookies(req);
  const token = cookies.autoclaw_session;
  const authed = !!(token && sessions.has(token));
  res.json({ ok: true, bootstrapped: !!a, authed });
});

app.post("/api/auth/bootstrap", (req, res) => {
  // Create the access code ONCE if not set.
  if (hasAuth()) {
    return res.status(400).json({ ok: false, error: "ALREADY_BOOTSTRAPPED" });
  }
  const code = generateCode(24);
  const record = pbkdf2Hash(code);
  record.createdAt = nowIso();
  record.note = "Store this code safely. It will not be shown again.";
  writeAuth(record);
  res.json({ ok: true, code, warning: "이 인증번호를 잊으면 서버 초기화가 필요할 수 있음" });
});

app.post("/api/auth/login", (req, res) => {
  const { code } = req.body || {};

  // NOTE: We intentionally avoid 4xx for user-typed mistakes (wrong/invalid code),
  // so browsers don't spam scary console errors during normal UX.
  if (!hasAuth()) return res.json({ ok: false, error: "NOT_BOOTSTRAPPED" });
  if (typeof code !== "string" || code.trim().length < 12) return res.json({ ok: false, error: "INVALID" });

  const record = readAuth();
  if (!pbkdf2Verify(code.trim(), record)) return res.json({ ok: false, error: "WRONG" });

  const token = newSessionToken();
  sessions.set(token, { createdAt: nowIso() });
  res.setHeader(
    "Set-Cookie",
    `autoclaw_session=${encodeURIComponent(token)}; HttpOnly; SameSite=Lax; Path=/`
  );
  res.json({ ok: true });
});

app.get("/api/env", async (req, res) => {
  const env = await detectEnv();
  const resources = await getMemSwap();
  // basic checks
  const checks = {
    curl: await cmdExists("curl"),
    git: await cmdExists("git"),
    jq: await cmdExists("jq"),
    ufw: await cmdExists("ufw"),
    lsof: await cmdExists("lsof"),
    node: await cmdExists("node"),
    pnpm: await cmdExists("pnpm"),
    npm: await cmdExists("npm"),
    openclaw: await cmdExists("openclaw"),
  };
  res.json({ ok: true, env, resources, checks });
});

app.get("/api/progress", async (req, res) => {
  const env = await detectEnv();
  const resources = await getMemSwap();
  const checks = {
    curl: await cmdExists("curl"),
    git: await cmdExists("git"),
    jq: await cmdExists("jq"),
    ufw: await cmdExists("ufw"),
    lsof: await cmdExists("lsof"),
    node: await cmdExists("node"),
    pnpm: await cmdExists("pnpm"),
    npm: await cmdExists("npm"),
    openclaw: await cmdExists("openclaw"),
  };

  const secretsPath = path.join(STATE_DIR, "secrets.json");
  const taskStatusPath = path.join(STATE_DIR, "task_status.json");
  const gatewayOkPath = path.join(STATE_DIR, "gateway_ok.json");
  const providerOkPath = path.join(STATE_DIR, "provider_ok.json");
  const channelsOkPath = path.join(STATE_DIR, "channels_ok.json");
  const nodeOkPath = path.join(STATE_DIR, "node_ok.json");
  const home = process.env.HOME || "";
  const openclawConfigPath = home ? path.join(home, ".openclaw", "openclaw.json") : "";

  const files = {
    secrets: fs.existsSync(secretsPath),
    openclawConfig: openclawConfigPath ? fs.existsSync(openclawConfigPath) : false,
    gatewayOk: fs.existsSync(gatewayOkPath),
    providerOk: fs.existsSync(providerOkPath),
    channelsOk: fs.existsSync(channelsOkPath),
    nodeOk: fs.existsSync(nodeOkPath),
    taskStatus: fs.existsSync(taskStatusPath),
  };

  let taskStatus = {};
  try {
    if (files.taskStatus) taskStatus = JSON.parse(fs.readFileSync(taskStatusPath, "utf8"));
  } catch {
    taskStatus = {};
  }

  // Persist detected progress for UX/debugging (best-effort)
  try {
    const outPath = path.join(STATE_DIR, "progress_detected.json");
    fs.writeFileSync(outPath, JSON.stringify({ ts: nowIso(), env, checks, files, taskStatus }, null, 2), "utf8");
  } catch {
    // ignore
  }

  res.json({ ok: true, env, resources, checks, files, taskStatus });
});

function getClientIp(req) {
  // NOTE: in IP-direct mode, we still expect the dashboard behind no proxy.
  // If you add a reverse proxy later, you must carefully set trusted proxies.
  const xf = req.headers["x-forwarded-for"];
  if (typeof xf === "string" && xf.length) return xf.split(",")[0].trim();
  const ra = req.socket?.remoteAddress || "";
  // Normalize IPv6-mapped IPv4
  if (ra.startsWith("::ffff:")) return ra.slice(7);
  return ra;
}

app.get("/api/status", (req, res) => {
  res.json({
    ok: true,
    now: nowIso(),
    clientIp: getClientIp(req),
    current,
  });
});

app.get("/api/log", (req, res) => {
  const id = req.query.id;
  if (!id) return res.status(400).json({ ok: false, error: "id required" });
  const logPath = path.join(RUN_DIR, `${id}.log`);
  if (!fs.existsSync(logPath)) return res.status(404).json({ ok: false, error: "log not found" });
  res.type("text/plain").send(fs.readFileSync(logPath, "utf8"));
});

app.get("/api/stream", (req, res) => {
  // Server-Sent Events: polls the log file.
  const id = req.query.id;
  if (!id) return res.status(400).end();
  const logPath = path.join(RUN_DIR, `${id}.log`);

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });

  let offset = 0;
  const timer = setInterval(() => {
    if (!fs.existsSync(logPath)) return;
    const buf = fs.readFileSync(logPath);
    if (buf.length <= offset) return;
    const chunk = buf.slice(offset);
    offset = buf.length;
    res.write(`event: log\n`);
    res.write(`data: ${JSON.stringify(chunk.toString())}\n\n`);

    // send status periodically too
    res.write(`event: status\n`);
    res.write(`data: ${JSON.stringify({ current })}\n\n`);
  }, 500);

  req.on("close", () => {
    clearInterval(timer);
  });
});

app.post("/api/run", (req, res) => {
  try {
    const { task, env } = req.body || {};
    if (!task) return res.status(400).json({ ok: false, error: "task required" });
    const job = runTask(task, env || {});
    res.json({ ok: true, job });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message || String(e) });
  }
});


app.post("/api/reset-wizard", (req, res) => {
  // Reset only the *wizard state* for selected steps.
  // Per user decision:
  // - reset step 1 (doctor) completion flag
  // - keep allowlist/ufw markers if they exist (do not weaken security)
  const taskStatusPath = path.join(STATE_DIR, "task_status.json");
  let taskStatus = {};
  try {
    if (fs.existsSync(taskStatusPath)) {
      taskStatus = JSON.parse(fs.readFileSync(taskStatusPath, "utf8"));
    }
  } catch {
    taskStatus = {};
  }

  if (taskStatus["doctor"]) {
    delete taskStatus["doctor"];
    try {
      fs.writeFileSync(taskStatusPath, JSON.stringify(taskStatus, null, 2), "utf8");
    } catch {
      // ignore
    }
  }
  // Back-compat: also clear old key if present
  if (taskStatus["00_doctor"]) {
    delete taskStatus["00_doctor"];
    try {
      fs.writeFileSync(taskStatusPath, JSON.stringify(taskStatus, null, 2), "utf8");
    } catch {
      // ignore
    }
  }

  res.json({ ok: true, reset: ["doctor"], kept: [] });
});

app.get("/api/secrets", (req, res) => {
  const secretsPath = path.join(STATE_DIR, "secrets.json");
  try {
    if (!fs.existsSync(secretsPath)) return res.json({ ok: true, secrets: {} });
    const secrets = JSON.parse(fs.readFileSync(secretsPath, "utf8"));
    res.json({ ok: true, secrets });
  } catch {
    res.json({ ok: true, secrets: {} });
  }
});

app.post("/api/save-secrets", (req, res) => {
  // Store user-provided values in a local JSON file (not committed).
  // IMPORTANT: This is a prototype; secrets handling needs hardening.
  const secretsPath = path.join(STATE_DIR, "secrets.json");
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const body = req.body || {};
  // Ensure extraEnv exists but defaults empty.
  if (body.extraEnv == null) body.extraEnv = {};
  fs.writeFileSync(secretsPath, JSON.stringify(body, null, 2), "utf8");
  res.json({ ok: true });
});

// --- Model catalog (from OpenClaw CLI) ---
let modelCache = { at: 0, json: null };

async function loadModelCatalog() {
  const now = Date.now();
  if (modelCache.json && (now - modelCache.at) < 60_000) return modelCache.json; // 60s cache

  const args = ["models", "list", "--all", "--json"];
  const proc = spawn("openclaw", args, {
    cwd: ROOT,
    env: { ...process.env },
  });

  let out = "";
  let err = "";
  proc.stdout.on("data", (d) => (out += d.toString()));
  proc.stderr.on("data", (d) => (err += d.toString()));

  const code = await new Promise((resolve) => proc.on("close", resolve));
  if (code !== 0) {
    throw new Error(`openclaw models list failed (code=${code}): ${err || out}`);
  }

  const json = JSON.parse(out);
  modelCache = { at: now, json };
  return json;
}

function providerFromKey(key) {
  const s = String(key || "");
  const idx = s.indexOf("/");
  return idx > 0 ? s.slice(0, idx) : "unknown";
}

app.get("/api/models", async (req, res) => {
  try {
    const provider = String(req.query.provider || "").trim();
    const catalog = await loadModelCatalog();
    const models = Array.isArray(catalog.models) ? catalog.models : [];

    const filtered = provider
      ? models.filter((m) => providerFromKey(m.key) === provider)
      : models;

    // Build provider list (from full catalog)
    const providers = Array.from(
      new Set(models.map((m) => providerFromKey(m.key)).filter(Boolean))
    ).sort();

    // Sort models by name then key for stable UI
    filtered.sort(
      (a, b) =>
        String(a.name).localeCompare(String(b.name)) ||
        String(a.key).localeCompare(String(b.key))
    );

    res.json({ ok: true, providers, count: filtered.length, models: filtered });
  } catch (e) {
    res
      .status(500)
      .json({ ok: false, error: String(e && e.message ? e.message : e) });
  }
});

// Live auth probe for a selected provider (best-effort)
app.post("/api/model-test", async (req, res) => {
  try {
    const body = req.body || {};
    const provider = String(body.provider || "").trim();

    if (!provider) {
      return res.status(400).json({ ok: false, error: "provider is required" });
    }

    const env = { ...process.env };
    if (provider === "openai" && body.openaiApiKey) env.OPENAI_API_KEY = String(body.openaiApiKey);
    if (provider === "anthropic" && body.anthropicApiKey) env.ANTHROPIC_API_KEY = String(body.anthropicApiKey);
    if (provider === "google" && body.geminiApiKey) env.GEMINI_API_KEY = String(body.geminiApiKey);

    const args = [
      "models",
      "status",
      "--probe",
      "--probe-provider",
      provider,
      "--json",
    ];

    const proc = spawn("openclaw", args, { cwd: ROOT, env });

    let out = "";
    let err = "";
    proc.stdout.on("data", (d) => (out += d.toString()));
    proc.stderr.on("data", (d) => (err += d.toString()));

    const code = await new Promise((resolve) => proc.on("close", resolve));

    if (code !== 0) {
      return res.json({ ok: false, code, error: (err || out || "probe failed").trim() });
    }

    let json = null;
    try {
      json = JSON.parse(out);
    } catch {
      // ignore
    }

    res.json({ ok: true, code: 0, result: json || { raw: out.trim() } });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e && e.message ? e.message : e) });
  }
});

const PORT = Number(process.env.AUTOCLAW_PORT || 8787);
const HOST = process.env.AUTOCLAW_BIND || "127.0.0.1";

app.listen(PORT, HOST, () => {
  console.log(`[autoclaw] dashboard listening on http://${HOST}:${PORT}`);

  void (async () => {
    const publicIp = (HOST === "0.0.0.0") ? await getPublicIp() : null;
    const url = publicIp ? `http://${publicIp}:${PORT}` : `http://<server-ip>:${PORT}`;

    let isWsl = false;
    try {
      const procVer = fs.readFileSync("/proc/version", "utf8");
      isWsl = /microsoft/i.test(procVer);
    } catch {
      // ignore
    }

    const hr = "────────────────────────────────────────────────────────────";
    const lines = [
      "",
      hr,
      "AutoClaw 대시보드 접속 방법",
      hr,
      `1) 브라우저에서 접속: ${url}`,
      "2) 첫 화면에서 ‘인증번호 생성’ → 반드시 기록",
      "3) 인증번호로 로그인 후 설치 마법사 진행",
      "",
      "인증번호를 잊었을 때(복구)",
      "- SSH로 접속 후 아래 파일 삭제 → 재접속 → 재발급",
      `  ${path.join(ROOT, "sh", "state", "auth.json")}`, 
      "",
      hr,
      "설치/실행 안내(중요)",
      hr,
      "- 이 터미널을 닫으면 AutoClaw 대시보드는 종료됩니다.",
      "- 설치가 끝난 뒤에는 AutoClaw 없이 OpenClaw만 운영해도 됩니다.",
      "  예) openclaw gateway start / openclaw gateway status", 
      "      openclaw node restart / openclaw node status",
      "",
      ...(isWsl
        ? [
            "[WSL 주의] WSL을 종료/셧다운하면 OpenClaw도 같이 종료됩니다.",
            "- 예: Windows PowerShell에서 wsl --shutdown 실행",
            "- 24/7 운영이 목적이면 VPS/상시 리눅스 환경을 권장합니다.",
            "",
          ]
        : []),
      "대시보드를 계속 실행하고 싶을 때(선택)",
      "- tmux(권장):",
      "  tmux new -s autoclaw",
      `  cd ${ROOT}`,
      `  AUTOCLAW_BIND=${HOST} AUTOCLAW_PORT=${PORT} node server/index.js`,
      "- nohup(백그라운드):",
      `  cd ${ROOT}`,
      `  nohup env AUTOCLAW_BIND=${HOST} AUTOCLAW_PORT=${PORT} node server/index.js > autoclaw.log 2>&1 &`,
      "",
      "자세한 내용은 GitHub README를 참고해 주세요:",
      "https://github.com/my3rdstory/autoclaw-web",
      hr,
      "",
    ];

    for (const l of lines) console.log(l);
  })();
});
