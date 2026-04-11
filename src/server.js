import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, resolve } from "node:path";

import { createMachineEntry, readMachines, updateMachineStatus, updateMachineSync } from "./store.js";
import { sendPromptToMachine, resolveMachineName, getCapture, getImageBuffer, approveAll, approveMachine, getAllSnapshots, getReachableMachines, getWatchdogState, setWatchdogEnabled, setMachineWatchdog, sendOnboardingToAll, startWatchdog, healthCheckAll, getTailscaleStatus, sleepMachine, wakeMachine, setTelegramEnabled, getTelegramEnabled } from "./ssh-exec.js";
import { addEntry, getHistory } from "./teamwork-store.js";

const PORT = 3030;
const HOST = "0.0.0.0";
const PUBLIC_DIR = resolve(import.meta.dirname, "../public");

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".svg": "image/svg+xml; charset=utf-8"
};
const VALID_STATUSES = new Set(["online", "idle", "busy", "offline", "maintenance"]);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};
const FRIENDLY_ROUTES = new Map([
  ["/control", "/teamwork.html"],
  ["/equipo", "/index.html"],
  ["/team", "/index.html"],
  ["/admin", "/consejo.html"],
  ["/consejo", "/consejo.html"],
  ["/alta", "/new-member.html?preset=ceo-macbook-air-clean"],
  ["/ceo", "/new-member.html?preset=ceo-macbook-air-clean"],
  ["/alta-ceo", "/new-member.html?preset=ceo-macbook-air-clean"],
  ["/creativa", "/new-member.html?preset=creative-macbook-air-clean"],
  ["/alta-creativa", "/new-member.html?preset=creative-macbook-air-clean"]
]);
const DEFAULT_ONBOARDING_PROMPT =
  "Haz onboarding leyendo el repositorio onboarding de Admira Next primero. Carga el contexto compartido, identifica los repositorios activos y queda listo para continuar sin pedir de nuevo el contexto base.";

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8", ...CORS_HEADERS });
  response.end(JSON.stringify(payload));
}

async function serveStatic(pathname, response) {
  const filePath = pathname === "/" ? resolve(PUBLIC_DIR, "index.html") : resolve(PUBLIC_DIR, `.${pathname}`);
  const ext = extname(filePath);
  const contentType = MIME_TYPES[ext] || "text/plain; charset=utf-8";
  try {
    const file = await readFile(filePath);
    response.writeHead(200, { "Content-Type": contentType });
    response.end(file);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
  }
}

function readRequestBody(request) {
  return new Promise((resolveBody, rejectBody) => {
    let body = "";
    request.on("data", (chunk) => {
      body += chunk;
    });
    request.on("end", () => resolveBody(body));
    request.on("error", rejectBody);
  });
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url || "/", `http://${request.headers.host}`);

  if (request.method === "OPTIONS") {
    response.writeHead(204, CORS_HEADERS);
    response.end();
    return;
  }

  if ((request.method === "GET" || request.method === "HEAD") && FRIENDLY_ROUTES.has(url.pathname)) {
    response.writeHead(302, { Location: FRIENDLY_ROUTES.get(url.pathname) });
    response.end();
    return;
  }

  if (url.pathname === "/api/machines") {
    if (request.method !== "GET" && request.method !== "POST") {
      sendJson(response, 405, { error: "Method not allowed" });
      return;
    }

    if (request.method === "GET") {
      const data = await readMachines();
      sendJson(response, 200, data);
      return;
    }

    if (request.method === "POST") {
      try {
        const rawBody = await readRequestBody(request);
        const parsed = rawBody ? JSON.parse(rawBody) : {};
        if (!VALID_STATUSES.has(parsed.status || "maintenance")) {
          sendJson(response, 400, { error: "Invalid status" });
          return;
        }

        const machine = await createMachineEntry(parsed);
        sendJson(response, 201, { ok: true, machine });
      } catch (error) {
        sendJson(response, 400, { error: error instanceof Error ? error.message : "No se pudo crear la maquina" });
      }
      return;
    }
  }

  if (request.method === "POST" && url.pathname.startsWith("/api/machines/") && url.pathname.endsWith("/power")) {
    const parts = url.pathname.split("/");
    const id = parts[3];
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const action = parsed.action;

    if (action !== "sleep" && action !== "wake") {
      sendJson(response, 400, { error: "action debe ser 'sleep' o 'wake'" });
      return;
    }

    const data = await readMachines();
    const machine = data.machines.find((m) => m.id === id);
    if (!machine) {
      sendJson(response, 404, { error: "Machine not found" });
      return;
    }

    const result = action === "sleep" ? await sleepMachine(machine) : await wakeMachine(machine);

    if (result.ok && action === "sleep") {
      await updateMachineStatus(id, "offline", "Sleep enviado desde dashboard");
    }

    sendJson(response, result.ok ? 200 : 502, { ...result, machine: id, action });
    return;
  }

  if (request.method === "POST" && url.pathname.startsWith("/api/machines/") && url.pathname.endsWith("/status")) {
    const parts = url.pathname.split("/");
    const id = parts[3];
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const status = parsed.status;
    const note = parsed.note ?? "";

    if (!VALID_STATUSES.has(status)) {
      sendJson(response, 400, { error: "Invalid status" });
      return;
    }

    const updated = await updateMachineStatus(id, status, note);
    if (!updated) {
      sendJson(response, 404, { error: "Machine not found" });
      return;
    }

    sendJson(response, 200, { ok: true, machine: updated });
    return;
  }

  // Power control: sleep/wake machines via SSH
  if (request.method === "POST" && url.pathname.startsWith("/api/machines/") && url.pathname.endsWith("/power")) {
    const parts = url.pathname.split("/");
    const id = parts[3];
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const action = parsed.action; // "sleep" or "wake"

    if (!action || !["sleep", "wake"].includes(action)) {
      sendJson(response, 400, { error: "Invalid action. Use 'sleep' or 'wake'" });
      return;
    }

    // Protect Mac Mini from accidental sleep
    if (id === "admira-macmini") {
      sendJson(response, 403, { error: "Cannot sleep the central server" });
      return;
    }

    // Resolve machine SSH details
    const machines = await readMachines();
    const machine = machines.machines?.find(m => m.id === id);
    if (!machine?.ssh?.ip_tailscale) {
      sendJson(response, 404, { error: "Machine not found or no SSH config" });
      return;
    }

    const user = machine.ssh.user || "csilvasantin";
    const ip = machine.ssh.ip_tailscale;
    const cmd = action === "sleep" ? "pmset sleepnow" : "caffeinate -u -t 5";

    const { execFile } = await import("node:child_process");
    const result = await new Promise((resolve_) => {
      execFile("ssh", [
        "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no",
        `${user}@${ip}`, cmd
      ], { timeout: 15000 }, (err, stdout, stderr) => {
        resolve_({ ok: !err, stdout, stderr: stderr || err?.message });
      });
    });

    sendJson(response, 200, { ok: result.ok, machine: id, action, detail: result.stdout || result.stderr });
    return;
  }

  if (request.method === "POST" && url.pathname.startsWith("/api/machines/") && url.pathname.endsWith("/sync")) {
    const parts = url.pathname.split("/");
    const id = parts[3];
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const status = parsed.status;

    if (!VALID_STATUSES.has(status)) {
      sendJson(response, 400, { error: "Invalid status" });
      return;
    }

    const updated = await updateMachineSync(id, {
      status,
      note: parsed.note ?? "",
      currentFocus: parsed.currentFocus ?? ""
    });

    if (!updated) {
      sendJson(response, 404, { error: "Machine not found" });
      return;
    }

    sendJson(response, 200, { ok: true, machine: updated });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/send") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    let { machineId, prompt, target } = parsed;
    target = target || "terminal";

    if (!machineId || !prompt) {
      sendJson(response, 400, { error: "machineId y prompt son obligatorios" });
      return;
    }

    prompt = prompt.trim();
    if (!prompt) {
      sendJson(response, 400, { error: "El prompt no puede estar vacío" });
      return;
    }

    const data = await readMachines();
    const machine = data.machines.find((m) => m.id === machineId);
    if (!machine) {
      const resolved = resolveMachineName(data.machines, machineId);
      if (resolved) {
        machineId = resolved.id;
      }
    }

    const result = await sendPromptToMachine(machineId, prompt, target);
    const entry = addEntry(machineId, result.name || machineId, prompt, result.ok, result.error, result.captureId, target);
    sendJson(response, result.ok ? 200 : 502, { ...result, entry });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/send-all") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const prompt = parsed.prompt?.trim();
    const target = parsed.target || "all";
    if (!prompt) {
      sendJson(response, 400, { error: "prompt obligatorio" });
      return;
    }

    const reachable = await getReachableMachines();
    const targets = target === "all" ? ["claude", "codex"] : [target];
    const results = await Promise.allSettled(
      reachable.flatMap((machine) =>
        targets.map((t) => sendPromptToMachine(machine.id, prompt, t))
      )
    );

    const output = results.map((r) => {
      const v = r.value || { ok: false, error: "rejected" };
      return { machine: v.name || v.machine, ok: v.ok, error: v.error };
    });
    sendJson(response, 200, { ok: true, results: output });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/onboarding-all") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const prompt = parsed.prompt?.trim() || DEFAULT_ONBOARDING_PROMPT;
    const results = await sendOnboardingToAll(prompt);
    sendJson(response, 200, { ok: true, prompt, results });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/approve") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const target = parsed.target || "claude";
    const onlyPending = parsed.onlyPending !== false; // default true
    const results = await approveAll(target, onlyPending);
    sendJson(response, 200, { ok: true, results });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/approve-machine") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    const { machineId, target } = parsed;
    if (!machineId) {
      sendJson(response, 400, { error: "machineId obligatorio" });
      return;
    }
    const result = await approveMachine(machineId, target || "claude");
    sendJson(response, 200, result);
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/teamwork/snapshots") {
    sendJson(response, 200, { ok: true, snapshots: getAllSnapshots() });
    return;
  }

  if (request.method === "GET" && url.pathname === "/api/teamwork/history") {
    sendJson(response, 200, { entries: getHistory() });
    return;
  }

  if (request.method === "GET" && url.pathname.startsWith("/api/teamwork/capture/")) {
    const captureId = url.pathname.split("/").pop();
    const capture = getCapture(captureId);
    if (capture) {
      sendJson(response, 200, { ok: true, ...capture });
    } else {
      sendJson(response, 202, { ok: false, pending: true });
    }
    return;
  }

  if (request.method === "GET" && url.pathname.startsWith("/api/screenshots/")) {
    const id = url.pathname.split("/").pop();
    const buf = getImageBuffer(id);
    if (buf) {
      response.writeHead(200, { "Content-Type": "image/jpeg", "Cache-Control": "no-cache, no-store, must-revalidate", ...CORS_HEADERS });
      response.end(buf);
    } else {
      response.writeHead(404, { "Content-Type": "text/plain" });
      response.end("Not found");
    }
    return;
  }

  // Health check endpoint
  if (request.method === "POST" && url.pathname === "/api/health-check") {
    const results = await healthCheckAll();
    sendJson(response, 200, { ok: true, results });
    return;
  }

  // Live Tailscale status endpoint
  if (request.method === "GET" && url.pathname === "/api/tailscale-status") {
    const peers = await getTailscaleStatus();
    if (!peers) {
      sendJson(response, 500, { error: "tailscale not available" });
      return;
    }
    // Merge with machines.json to map hostnames to machine IDs
    const data = await readMachines();
    const merged = {};
    for (const m of data.machines) {
      // Derive tailscale hostname from ssh.host or machine id
      const tsHost = (m.ssh?.host || m.id.replace("admira-", "")).toLowerCase();
      const peer = peers[tsHost];
      merged[m.id] = {
        id: m.id,
        name: m.name,
        tailscale: peer || null,
        online: peer ? peer.online : false,
        active: peer ? peer.active : false,
        ip: peer?.ip || m.ssh?.ip_tailscale || "",
        lastSeen: peer?.lastSeen || m.lastSeen || "",
      };
    }
    sendJson(response, 200, { ok: true, updatedAt: new Date().toISOString(), machines: merged });
    return;
  }

  // Watchdog endpoints
  if (request.method === "GET" && url.pathname === "/api/teamwork/watchdog") {
    sendJson(response, 200, { ok: true, ...getWatchdogState() });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/watchdog") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    setWatchdogEnabled(!!parsed.enabled);
    sendJson(response, 200, { ok: true, enabled: !!parsed.enabled });
    return;
  }

  if (request.method === "POST" && url.pathname === "/api/teamwork/watchdog/machine") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    if (!parsed.machineId) {
      sendJson(response, 400, { error: "machineId obligatorio" });
      return;
    }
    setMachineWatchdog(parsed.machineId, !!parsed.enabled);
    sendJson(response, 200, { ok: true, machineId: parsed.machineId, enabled: !!parsed.enabled });
    return;
  }

  // Telegram alerts toggle
  if (request.method === "GET" && url.pathname === "/api/teamwork/telegram") {
    sendJson(response, 200, { ok: true, enabled: getTelegramEnabled() });
    return;
  }
  if (request.method === "POST" && url.pathname === "/api/teamwork/telegram") {
    const rawBody = await readRequestBody(request);
    const parsed = rawBody ? JSON.parse(rawBody) : {};
    setTelegramEnabled(!!parsed.enabled);
    sendJson(response, 200, { ok: true, enabled: !!parsed.enabled });
    return;
  }

  await serveStatic(url.pathname, response);
});

server.listen(PORT, HOST, async () => {
  console.log(`AdmiraNext Team escuchando en http://${HOST}:${PORT}`);
  console.log("Ejecutando health check de máquinas...");
  await healthCheckAll();
  startWatchdog(); // Auto-Approve ON por defecto al arrancar
  // Health check periódico cada 60s
  setInterval(async () => {
    try { await healthCheckAll(); } catch (e) { console.error("Health check error:", e.message); }
  }, 60_000);
});
