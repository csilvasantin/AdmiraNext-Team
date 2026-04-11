const quickInput = document.querySelector("#quickInput");
const sendAllBtn = document.querySelector("#sendAllBtn");
const onboardingAllBtn = document.querySelector("#onboardingAllBtn");
const sendAllTarget = document.querySelector("#sendAllTarget");
const feedback = document.querySelector("#feedback");
const historyList = document.querySelector("#historyList");

let machines = [];
let isStaticMode = false;
const FUNNEL_URL = "https://macmini.tail48b61c.ts.net";
const FUNNEL_HOST = "macmini.tail48b61c.ts.net";
const isLocal = location.hostname === "localhost" || location.hostname === "127.0.0.1" || location.hostname === FUNNEL_HOST;
const DEFAULT_ONBOARDING_PROMPT =
  "Haz onboarding leyendo el repositorio onboarding de Admira Next primero. Carga el contexto compartido, identifica los repositorios activos y queda listo para continuar sin pedir de nuevo el contexto base.";
const LOCAL_ONBOARDING_COMMANDS = new Set(["onboarding", "haz onboarding"]);
const GLOBAL_ONBOARDING_COMMANDS = new Set(["onboarding all", "haz onboarding all"]);
const GROUP_LABELS = {
  council: "Consejo de Administracion",
  worker: "Equipo"
};
const LIVE_PREVIEW_WINDOW_MS = 10 * 60 * 1000;
let tailscaleData = {}; // Cache of live Tailscale status per machine ID

function timeAgo(iso) {
  if (!iso) return "—";
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60000) return "ahora";
  if (diff < 3600000) return `hace ${Math.floor(diff / 60000)}m`;
  if (diff < 86400000) return `hace ${Math.floor(diff / 3600000)}h`;
  return `hace ${Math.floor(diff / 86400000)}d`;
}

// Redirect GitHub Pages to Funnel
if (location.hostname === "csilvasantin.github.io") {
  location.href = FUNNEL_URL + "/teamwork.html";
}

function apiUrl(path) {
  return isLocal ? path : `${FUNNEL_URL}${path}`;
}

function normalizeCommand(text) {
  return text.trim().toLowerCase().replace(/\s+/g, " ");
}

function showFeedback(text, ok) {
  feedback.textContent = text;
  feedback.className = "tw-feedback " + (ok ? "ok" : "err");
  setTimeout(() => { feedback.className = "tw-feedback"; }, 4000);
}

function syncTopActionVisibility() {
  const readonly = isStaticMode;
  if (sendAllTarget) sendAllTarget.hidden = readonly;
  if (sendAllBtn) sendAllBtn.hidden = readonly;
  if (onboardingAllBtn) onboardingAllBtn.hidden = readonly;
}

function formatTime(iso) {
  try {
    return new Date(iso).toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  } catch {
    return iso;
  }
}

function resolveName(input) {
  const q = input.toLowerCase().replace(/[\s\-_]+/g, "");
  return machines.find((m) => {
    const id = m.id.toLowerCase().replace(/[\s\-_]+/g, "");
    const name = m.name.toLowerCase().replace(/[\s\-_]+/g, "");
    return id.includes(q) || name.includes(q) || id.replace("admira", "").includes(q);
  }) || null;
}

function parseQuickInput(text) {
  const trimmed = text.trim();
  if (!trimmed) return null;

  for (const m of machines) {
    const names = [
      m.id,
      m.id.replace("admira-", ""),
      m.name
    ];
    for (const alias of names) {
      if (trimmed.toLowerCase().startsWith(alias.toLowerCase())) {
        const rest = trimmed.slice(alias.length).trim();
        if (rest) return { machineId: m.id, prompt: rest };
      }
    }
  }

  const parts = trimmed.split(/\s+/);
  const first = parts[0];
  const resolved = resolveName(first);
  if (resolved && parts.length > 1) {
    return { machineId: resolved.id, prompt: parts.slice(1).join(" ") };
  }

  return null;
}

async function sendToAll(prompt) {
  if (isStaticMode) {
    showFeedback("Panel en solo lectura en esta URL publica.", false);
    return;
  }
  sendAllBtn.disabled = true;
  const target = sendAllTarget.value;
  sendAllBtn.textContent = "Enviando...";

  try {
    const res = await fetch(apiUrl("/api/teamwork/send-all"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt, target })
    });
    const data = await res.json();
    const ok = data.results.filter((r) => r.ok).length;
    const skipped = data.results.filter((r) => r.skipped).length;
    const label = target === "all" ? "Claude + Codex" : target.charAt(0).toUpperCase() + target.slice(1);
    const extra = skipped ? ` (${skipped} sin app abierta)` : "";
    showFeedback(`Enviado a ${ok} equipos con ${label}${extra}`, ok > 0);
    quickInput.value = "";
  } catch (err) {
    showFeedback(`Error: ${err.message}`, false);
  }

  sendAllBtn.disabled = false;
  sendAllBtn.textContent = "Enviar";
  loadHistory();
}

async function sendOnboardingAll(prompt = DEFAULT_ONBOARDING_PROMPT) {
  if (isStaticMode) {
    showFeedback("Panel en solo lectura en esta URL publica.", false);
    return;
  }
  onboardingAllBtn.disabled = true;
  sendAllBtn.disabled = true;
  onboardingAllBtn.textContent = "Lanzando...";

  try {
    const res = await fetch(apiUrl("/api/teamwork/onboarding-all"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt })
    });
    const data = await res.json();
    const ok = data.results.filter((r) => r.ok).length;
    const offline = data.results.filter((r) => r.skipped).length;
    const fail = data.results.filter((r) => !r.ok && !r.skipped).length;
    const parts = [`${ok} equipos actualizados`];
    if (offline) parts.push(`${offline} offline`);
    if (fail) parts.push(`${fail} con error`);
    showFeedback(`Onboarding all lanzado: ${parts.join(" | ")}`, ok > 0);
    quickInput.value = "";
  } catch (err) {
    showFeedback(`Error: ${err.message}`, false);
  }

  onboardingAllBtn.disabled = false;
  sendAllBtn.disabled = false;
  onboardingAllBtn.textContent = "Onboarding all";
  loadHistory();
}

async function handleQuickCommand(prompt) {
  const normalized = normalizeCommand(prompt);

  if (LOCAL_ONBOARDING_COMMANDS.has(normalized)) {
    showFeedback("`onboarding` es local: hazlo en esta sesion. Usa `onboarding all` si quieres refrescar todo AdmiraNext.", false);
    return true;
  }

  if (GLOBAL_ONBOARDING_COMMANDS.has(normalized)) {
    await sendOnboardingAll();
    return true;
  }

  return false;
}

function renderHistory(entries) {
  if (!entries.length) {
    historyList.innerHTML = '<p class="tw-empty">Sin comandos enviados todavía.</p>';
    return;
  }

  historyList.innerHTML = entries.map((e) => {
    const captureHtml = e.captureId
      ? `<div class="tw-terminal" id="capture-${e.captureId}"><span class="tw-terminal-loading">Capturando terminal...</span></div>`
      : "";
    return `
      <div class="tw-entry">
        <div class="tw-entry-header">
          <span class="tw-entry-machine">${e.machineName} <span class="tw-entry-target">${e.target || "terminal"}</span><span class="tw-entry-status ${e.status}"></span></span>
          <span class="tw-entry-prompt">${e.prompt}</span>
          <span class="tw-entry-time">${formatTime(e.sentAt)}</span>
        </div>
        ${captureHtml}
      </div>`;
  }).join("");

  // Load terminal captures
  for (const e of entries) {
    if (e.captureId) loadCapture(e.captureId);
  }
}

async function loadCapture(captureId) {
  const el = document.querySelector(`#capture-${captureId}`);
  if (!el || el.dataset.loaded === "true") return;

  try {
    const res = await fetch(apiUrl(`/api/teamwork/capture/${captureId}`), { cache: "no-store" });
    const data = await res.json();
    if (data.ok) {
      if (data.type === "image") {
        el.className = "tw-screenshot";
        el.innerHTML = `<img src="${apiUrl(data.path)}" alt="Captura de pantalla" loading="lazy">`;
      } else if (data.type === "text") {
        el.className = "tw-terminal";
        el.innerHTML = `<pre>${data.text.replace(/</g, "&lt;")}</pre>`;
      }
      el.dataset.loaded = "true";
    }
  } catch {
    // will retry on next poll
  }
}

async function loadHistory() {
  try {
    const res = await fetch(apiUrl("/api/teamwork/history"), { cache: "no-store" });
    const data = await res.json();
    renderHistory(data.entries || []);
  } catch {
    // silently fail
  }
}

async function loadTailscaleStatus() {
  if (isStaticMode) return;
  try {
    const res = await fetch(apiUrl("/api/tailscale-status"), { cache: "no-store" });
    if (!res.ok) return;
    const data = await res.json();
    tailscaleData = data.machines || {};
    // Merge live status into machines array
    for (const m of machines) {
      const ts = tailscaleData[m.id];
      if (ts) {
        m.status = ts.online ? (ts.active ? "online" : "idle") : "offline";
        if (ts.ip) m._tsIp = ts.ip;
        if (ts.lastSeen) m._tsLastSeen = ts.lastSeen;
        if (ts.tailscale?.curAddr) m._tsCurAddr = ts.tailscale.curAddr;
      }
    }
  } catch { /* silently fail */ }
}

async function loadMachines() {
  try {
    const res = await fetch(apiUrl("/api/machines"), { cache: "no-store" });
    if (!res.ok) throw new Error("api unavailable");
      const data = await res.json();
      machines = data.machines;
      isStaticMode = false;
      await loadTailscaleStatus();
      syncTopActionVisibility();
      renderMachineApproveList(null);
    } catch {
      try {
        const res = await fetch("./machines.json?v=20260331-4", { cache: "no-store" });
        const data = await res.json();
        machines = data.machines;
        isStaticMode = true;
        syncTopActionVisibility();
        renderMachineApproveList(null);
      } catch {
        // no machines
      }
  }
}

// Per-machine approve
const machineApproveList = document.querySelector("#machineApproveList");

function formatTimeShort(iso) {
  try { return new Date(iso).toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" }); }
  catch { return ""; }
}

function hasLivePreview(machine, snapshots) {
  const snap = snapshots?.[machine.id];
  if (!snap?.updatedAt) return false;
  const updatedAt = new Date(snap.updatedAt).getTime();
  if (!Number.isFinite(updatedAt)) return false;
  const hasVisual =
    (snap.type === "image" && Boolean(snap.image)) ||
    (snap.type === "images" && Array.isArray(snap.images) && snap.images.length > 0) ||
    Boolean(snap.text);
  return hasVisual && (Date.now() - updatedAt) <= LIVE_PREVIEW_WINDOW_MS;
}

function renderMachineRow(m, snapshots) {
  const group = m.unitType || "council";
  const snap = snapshots?.[m.id];
  const remoteReady = !isStaticMode && Boolean(m.ssh?.enabled || m.automation?.enabled);
  const defaultTarget = m.platform === "Windows" ? "terminal" : "claude";
  let monitorContent;
  const multiLabels = ["Claude", "Studio", "Codex"];

  if (snap && snap.type === "images") {
    const t = Date.now();
    const orients = snap.orientations || snap.images.map(() => "portrait");
    monitorContent = `<div class="tw-multi-monitor">${snap.images.map((imgPath, i) => {
      const src = (imgPath.startsWith("/") ? apiUrl(imgPath) : imgPath) + `?t=${t}`;
      return `<div class="tw-multi-screen ${orients[i]}"><img src="${src}" alt="${multiLabels[i]}"><span class="tw-screen-label">${multiLabels[i]}</span></div>`;
    }).join("")}</div><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
  } else if (snap && snap.type === "image") {
    const imgSrc = snap.image.startsWith("/") ? apiUrl(snap.image) : snap.image;
    const cacheBust = imgSrc.includes("?") ? `&t=${Date.now()}` : `?t=${Date.now()}`;
    monitorContent = `<img src="${imgSrc}${cacheBust}" alt="${m.name}" style="width:100%;height:100%;object-fit:cover;border-radius:6px;"><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
  } else if (snap && snap.text) {
    monitorContent = `<pre>${snap.text.replace(/</g, "&lt;")}</pre><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
  } else {
    monitorContent = `<div class="tw-machine-monitor-empty">Sin señal</div>`;
  }

  return `
    <div class="tw-machine-row tw-machine-row-${group}" data-id="${m.id}">
      <div class="tw-machine-monitor small" data-monitor="${m.id}">${monitorContent}</div>
      <div class="tw-machine-body">
      <div class="tw-machine-label">
        <span class="tw-machine-name">${m.name}</span>
        <span class="tw-status-pill ${m.status || "offline"}">${m.status || "offline"}</span><br>
        <span class="tw-machine-member">${m.member} · ${m.platform}${m.role ? " · " + m.role : ""}</span>
        ${m.unitType === "worker" ? `<div class="tw-machine-caps"><span class="tw-machine-cap tw-machine-cap-kind">PC</span>${(m.capabilities || []).map((cap) => `<span class="tw-machine-cap">${cap}</span>`).join("")}</div>` : ""}
        <span class="tw-info-wrapper">
          <button class="tw-info-btn" data-info-toggle="${m.id}" title="Info del equipo">ℹ</button>
          <div class="tw-info-dropdown" data-info-panel="${m.id}">
            <div class="tw-info-title">
              <span class="tw-info-status ${m.status || "offline"}"></span>
              ${m.name}
              ${m.role ? `<span class="tw-info-badge">${m.role}</span>` : ""}
            </div>
            <div class="tw-info-row"><span class="tw-info-key">Operador</span><span class="tw-info-val">${m.member || "—"}</span></div>
            <div class="tw-info-row"><span class="tw-info-key">Funcion</span><span class="tw-info-val">${m.machineRole || "—"}</span></div>
            <div class="tw-info-row"><span class="tw-info-key">Plataforma</span><span class="tw-info-val">${m.platform || "—"}</span></div>
            <div class="tw-info-row"><span class="tw-info-key">Ubicacion</span><span class="tw-info-val">${m.location || "—"}</span></div>
            <div class="tw-info-row"><span class="tw-info-key">Estado</span><span class="tw-info-val" style="color:${m.status === "online" ? "#2d6a4f" : m.status === "idle" ? "#3e7ea0" : "#8b5b63"}">${m.status || "desconocido"}</span></div>
            ${m.ssh?.ip_tailscale || m._tsIp ? `<div class="tw-info-row"><span class="tw-info-key">IP Tailscale</span><span class="tw-info-val" style="font-family:monospace;font-size:10px">${m._tsIp || m.ssh.ip_tailscale}</span></div>` : ""}
            ${m.ssh?.host ? `<div class="tw-info-row"><span class="tw-info-key">SSH</span><span class="tw-info-val tw-ssh-copy" style="font-size:10px;cursor:pointer" title="Clic para copiar" onclick="event.stopPropagation(); navigator.clipboard.writeText('ssh ${m.ssh.user || "csilvasantin"}@${m.ssh.ip_tailscale || m.ssh.host}'); this.textContent='Copiado!'; setTimeout(()=>this.textContent='${m.ssh.user || "csilvasantin"}@${m.ssh.host}',1500)">${m.ssh.user || "csilvasantin"}@${m.ssh.host}</span></div>` : ""}
            <div class="tw-info-row"><span class="tw-info-key">Ultima vez</span><span class="tw-info-val">${timeAgo(m._tsLastSeen || m.lastSeen)}</span></div>
            ${snap?.updatedAt ? `<div class="tw-info-row"><span class="tw-info-key">Captura</span><span class="tw-info-val">${timeAgo(snap.updatedAt)}</span></div>` : ""}
            ${snap?.claudeState || snap?.codexState ? `<div class="tw-info-row"><span class="tw-info-key">Apps</span><span class="tw-info-val">${snap?.claudeState ? '<span style="color:#d63031">C:</span>' + snap.claudeState : ""} ${snap?.codexState ? '<span style="color:#0984e3">X:</span>' + snap.codexState : ""}</span></div>` : ""}
            ${m.agentProfile ? `<div class="tw-info-row"><span class="tw-info-key">Perfil agente</span><span class="tw-info-val">${m.agentProfile}</span></div>` : ""}
            ${(m.capabilities || []).length ? `<div class="tw-info-row"><span class="tw-info-key">Capacidades</span><span class="tw-info-val">${m.capabilities.join(", ")}</span></div>` : ""}
            ${m.currentFocus ? `<div class="tw-info-focus"><div class="tw-info-focus-label">Foco actual</div>${m.currentFocus}</div>` : ""}
            ${m.note ? `<div class="tw-info-focus"><div class="tw-info-focus-label">Nota</div>${m.note}</div>` : ""}
          </div>
        </span>
      </div>
      <div class="tw-machine-actions">
        <input class="tw-machine-input" data-machine="${m.id}" type="text" placeholder="Prompt para ${m.member}..." ${remoteReady ? "" : "disabled"}>
        <select class="tw-approve-sm" data-machine-target="${m.id}" style="background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 6px;font-size:11px;border-radius:10px;">
          <option value="claude" ${defaultTarget === "claude" ? "selected" : ""}>Claude</option>
          <option value="codex" ${defaultTarget === "codex" ? "selected" : ""}>Codex</option>
          <option value="terminal" ${defaultTarget === "terminal" ? "selected" : ""}>Terminal</option>
        </select>
        <button class="tw-machine-send" data-machine-send="${m.id}" ${remoteReady ? "" : "disabled"}>${remoteReady ? "Enviar" : "Pendiente"}</button>
        <button class="tw-machine-approve" data-machine-approve="${m.id}" ${remoteReady ? "" : "disabled"}>${remoteReady ? "Aprobar" : "Sin canal"}</button>
        <span class="tw-auto-badge ${m.status === "online" || m.status === "busy" ? "" : "tw-auto-badge-off"}" data-watchdog-machine="${m.id}">${remoteReady ? "🤖 0" : m.status || "offline"}</span>
      </div>
      </div>
    </div>`;
}

function renderMachineApproveList(snapshots) {
  const filtered = machines;
  if (!filtered.length) {
    machineApproveList.innerHTML = '<p class="tw-empty">Sin equipos disponibles.</p>';
    return;
  }

  const sortWithinGroup = (items) => [...items].sort((a, b) => {
    const aOnline = snapshots?.[a.id] ? 1 : 0;
    const bOnline = snapshots?.[b.id] ? 1 : 0;
    return bOnline - aOnline;
  });

  const grouped = {
    council: sortWithinGroup(filtered.filter((m) => (m.unitType || "council") === "council")),
    worker: sortWithinGroup(filtered.filter((m) => (m.unitType || "council") === "worker"))
  };

  const sections = [];
  for (const group of ["council", "worker"]) {
    const items = grouped[group];
    if (!items.length) continue;
    const shouldExpand = items.some((m) => hasLivePreview(m, snapshots));
    const expanded = shouldExpand ? "true" : "false";
    const hidden = shouldExpand ? "" : "hidden";
    const onlineCount = items.filter((m) => m.status === "online" || m.status === "idle" || m.status === "busy").length;
    sections.push(`
      <section class="tw-group-block tw-group-block-${group}">
        <button class="tw-group-toggle tw-group-${group}" data-group-toggle="${group}" aria-expanded="${expanded}" type="button">
          <span>${GROUP_LABELS[group] || group} <span class="tw-group-count">${onlineCount}/${items.length} online</span></span>
          <span class="tw-group-toggle-icon">${shouldExpand ? "−" : "+"}</span>
        </button>
        <div class="tw-group-rows" data-group-panel="${group}" ${hidden}>
          ${items.map((m) => renderMachineRow(m, snapshots)).join("")}
        </div>
      </section>
    `);
  }
  machineApproveList.innerHTML = sections.join("");

  machineApproveList.querySelectorAll("[data-group-toggle]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const group = btn.dataset.groupToggle;
      const panel = machineApproveList.querySelector(`[data-group-panel="${group}"]`);
      const expanded = btn.getAttribute("aria-expanded") === "true";
      btn.setAttribute("aria-expanded", expanded ? "false" : "true");
      const icon = btn.querySelector(".tw-group-toggle-icon");
      if (icon) icon.textContent = expanded ? "+" : "−";
      if (panel) panel.hidden = expanded;
    });
  });

  // Per-machine send prompt
  machineApproveList.querySelectorAll(".tw-machine-send").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const machineId = btn.dataset.machineSend;
      const input = machineApproveList.querySelector(`.tw-machine-input[data-machine="${machineId}"]`);
      const targetSel = machineApproveList.querySelector(`select[data-machine-target="${machineId}"]`);
      const prompt = input?.value.trim();
      if (!prompt) return;

      btn.disabled = true;
      btn.textContent = "...";

      try {
        const res = await fetch(apiUrl("/api/teamwork/send"), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ machineId, prompt, target: targetSel?.value || "claude" })
        });
        const data = await res.json();
        btn.textContent = data.ok ? "OK" : "Error";
        if (data.ok) input.value = "";
        setTimeout(() => { btn.textContent = "Enviar"; btn.disabled = false; }, 2000);
        loadHistory();
      } catch {
        btn.textContent = "Error";
        setTimeout(() => { btn.textContent = "Enviar"; btn.disabled = false; }, 2000);
      }
    });
  });

  // Per-machine approve
  machineApproveList.querySelectorAll(".tw-machine-approve").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const machineId = btn.dataset.machineApprove;
      const targetSel = machineApproveList.querySelector(`select[data-machine-target="${machineId}"]`);
      const target = targetSel?.value || "claude";
      btn.disabled = true;
      btn.textContent = "⏳";

      try {
        const res = await fetch(apiUrl("/api/teamwork/approve-machine"), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ machineId, target })
        });
        const data = await res.json();
        if (data.ok) {
          btn.textContent = "✅";
          btn.style.background = "#0984e3";
          // Refresh snapshot for this machine after 3s
          setTimeout(loadSnapshots, 3000);
        } else {
          btn.textContent = data.error === "offline" ? "⏭️ Offline" : "❌";
          btn.style.background = "#c1121f";
        }
        setTimeout(() => {
          btn.textContent = "Aprobar";
          btn.style.background = "";
          btn.disabled = false;
        }, 3000);
      } catch {
        btn.textContent = "❌";
        setTimeout(() => { btn.textContent = "Aprobar"; btn.style.background = ""; btn.disabled = false; }, 2000);
      }
    });
  });

  // Toggle monitor size
  machineApproveList.querySelectorAll(".tw-machine-monitor").forEach((mon) => {
    mon.addEventListener("click", () => {
      mon.classList.toggle("small");
      mon.classList.toggle("expanded");
    });
  });

  // Toggle machine info dropdown
  machineApproveList.querySelectorAll(".tw-info-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const id = btn.dataset.infoToggle;
      const panel = machineApproveList.querySelector(`.tw-info-dropdown[data-info-panel="${id}"]`);
      const wasOpen = panel.classList.contains("open");
      // Close all open dropdowns first
      machineApproveList.querySelectorAll(".tw-info-dropdown.open").forEach((p) => p.classList.remove("open"));
      machineApproveList.querySelectorAll(".tw-info-btn.open").forEach((b) => b.classList.remove("open"));
      if (!wasOpen) {
        panel.classList.add("open");
        btn.classList.add("open");
      }
    });
  });
  // Close info dropdown when clicking outside
  document.addEventListener("click", () => {
    machineApproveList.querySelectorAll(".tw-info-dropdown.open").forEach((p) => p.classList.remove("open"));
    machineApproveList.querySelectorAll(".tw-info-btn.open").forEach((b) => b.classList.remove("open"));
  });

  // Enter to send per-machine
  machineApproveList.querySelectorAll(".tw-machine-input").forEach((input) => {
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        const machineId = input.dataset.machine;
        machineApproveList.querySelector(`.tw-machine-send[data-machine-send="${machineId}"]`)?.click();
      }
    });
  });
}

// Approve buttons
const approveClaudeBtn = document.querySelector("#approveClaudeBtn");
const approveCodexBtn = document.querySelector("#approveCodexBtn");
const approveClaudeResult = document.querySelector("#approveClaudeResult");
const approveCodexResult = document.querySelector("#approveCodexResult");

async function approveAll(target, btn, resultEl) {
  btn.disabled = true;
  btn.textContent = "...";
  resultEl.textContent = "";
  resultEl.className = "tw-approve-result";

  try {
    const res = await fetch(apiUrl("/api/teamwork/approve"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ target, onlyPending: true })
    });
    const data = await res.json();
    const okList = data.results.filter((r) => r.ok);
    const failList = data.results.filter((r) => !r.ok && !r.skipped);
    const skipped = data.results.filter((r) => r.skipped);

    const parts = [];
    for (const r of okList) parts.push(`✅ ${r.machine}`);
    for (const r of failList) parts.push(`❌ ${r.machine}`);
    if (skipped.length) parts.push(`⏭️ ${skipped.length} sin app`);

    if (okList.length === 0 && failList.length === 0) {
      resultEl.innerHTML = `Sin equipos con ${target === "claude" ? "Claude" : "Codex"} pendiente`;
      resultEl.classList.add("tw-approve-error");
    } else {
      resultEl.innerHTML = `<strong>${okList.length} aprobados</strong> — ${parts.join(" | ")}`;
      resultEl.classList.add(okList.length > 0 ? "tw-approve-success" : "tw-approve-error");
    }

    const savedResult = resultEl.innerHTML;
    const savedClass = resultEl.className;
    setTimeout(() => {
      loadSnapshots();
      setTimeout(() => {
        resultEl.innerHTML = savedResult;
        resultEl.className = savedClass;
      }, 500);
    }, 4000);
  } catch (err) {
    resultEl.textContent = `Error: ${err.message}`;
    resultEl.classList.add("tw-approve-error");
  }

  btn.disabled = false;
  btn.textContent = target === "claude" ? "Claude" : "Codex";
}

quickInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") {
    e.preventDefault();
    const prompt = quickInput.value.trim();
    if (prompt) {
      handleQuickCommand(prompt).then((handled) => {
        if (!handled) sendToAll(prompt);
      });
    }
    else showFeedback("Escribe un prompt", false);
  }
});

sendAllBtn.addEventListener("click", () => {
  const prompt = quickInput.value.trim();
  if (prompt) {
    handleQuickCommand(prompt).then((handled) => {
      if (!handled) sendToAll(prompt);
    });
  }
  else showFeedback("Escribe un prompt", false);
});

onboardingAllBtn.addEventListener("click", () => sendOnboardingAll());

approveClaudeBtn.addEventListener("click", () => approveAll("claude", approveClaudeBtn, approveClaudeResult));
approveCodexBtn.addEventListener("click", () => approveAll("codex", approveCodexBtn, approveCodexResult));

function updateSnapshotsInPlace(snapshots) {
  for (const m of machines) {
    const row = machineApproveList.querySelector(`.tw-machine-row[data-id="${m.id}"]`);
    if (!row) return renderMachineApproveList(snapshots); // first render
    const mon = row.querySelector(".tw-machine-monitor");
    const snap = snapshots?.[m.id];
    const multiLabels = ["Studio", "Claude", "Codex"];
    if (snap && snap.type === "images") {
      const t = Date.now();
      const imgs = mon.querySelectorAll(".tw-multi-screen img");
      if (imgs.length === snap.images.length) {
        snap.images.forEach((imgPath, i) => {
          const src = (imgPath.startsWith("/") ? apiUrl(imgPath) : imgPath) + `?t=${t}`;
          const preload = new Image();
          preload.onload = () => { imgs[i].src = src; };
          preload.src = src;
        });
        const timeEl = mon.querySelector(".tw-machine-monitor-time");
        if (timeEl) timeEl.textContent = formatTimeShort(snap.updatedAt);
      } else {
        const orients = snap.orientations || snap.images.map(() => "portrait");
        mon.innerHTML = `<div class="tw-multi-monitor">${snap.images.map((imgPath, i) => {
          const src = (imgPath.startsWith("/") ? apiUrl(imgPath) : imgPath) + `?t=${t}`;
          return `<div class="tw-multi-screen ${orients[i]}"><img src="${src}" alt="${multiLabels[i]}"><span class="tw-screen-label">${multiLabels[i]}</span></div>`;
        }).join("")}</div><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
      }
    } else if (snap && snap.type === "image") {
      const imgSrc = snap.image.startsWith("/") ? apiUrl(snap.image) : snap.image;
      const cacheBust = imgSrc.includes("?") ? `&t=${Date.now()}` : `?t=${Date.now()}`;
      const newSrc = `${imgSrc}${cacheBust}`;
      const img = mon.querySelector("img");
      if (img) {
        const preload = new Image();
        preload.onload = () => {
          img.src = newSrc;
          const timeEl = mon.querySelector(".tw-machine-monitor-time");
          if (timeEl) timeEl.textContent = formatTimeShort(snap.updatedAt);
        };
        preload.src = newSrc;
      } else {
        mon.innerHTML = `<img src="${newSrc}" alt="${m.name}" style="width:100%;height:100%;object-fit:cover;border-radius:6px;"><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
      }
    } else if (snap && snap.text) {
      mon.innerHTML = `<pre>${snap.text.replace(/</g, "&lt;")}</pre><span class="tw-machine-monitor-time">${formatTimeShort(snap.updatedAt)}</span>`;
    }
    // Update app badges
    const statusEl = row.querySelector(".tw-app-status");
    if (statusEl) {
      statusEl.innerHTML =
        (snap?.claudeState ? `<span class="tw-app-tag claude" title="Claude: ${snap.claudeState}">C</span>` : "") +
        (snap?.codexState ? `<span class="tw-app-tag codex" title="Codex: ${snap.codexState}">X</span>` : "");
    }
  }

  // Re-sort rows dentro de su grupo para no romper el acordeon
  for (const group of ["council", "worker"]) {
    const panel = machineApproveList.querySelector(`[data-group-panel="${group}"]`);
    if (!panel) continue;
    const rows = [...panel.querySelectorAll(".tw-machine-row")];
    const sorted = [...rows].sort((a, b) => (snapshots?.[b.dataset.id] ? 1 : 0) - (snapshots?.[a.dataset.id] ? 1 : 0));
    const orderChanged = rows.some((r, i) => r !== sorted[i]);
    if (orderChanged) sorted.forEach((row) => panel.appendChild(row));
  }
}

async function loadSnapshots() {
  try {
    const res = await fetch(apiUrl("/api/teamwork/snapshots"), { cache: "no-store" });
    const data = await res.json();
    if (data.ok) {
      const hasRows = machineApproveList.querySelector(".tw-machine-row");
      if (hasRows) {
        updateSnapshotsInPlace(data.snapshots);
      } else {
        renderMachineApproveList(data.snapshots);
      }
    }
  } catch {
    // silently fail
  }
}

// ─── Watchdog toggle & stats ───────────────────────────────────────

const watchdogToggle = document.querySelector("#watchdogToggle");
const watchdogPulse = document.querySelector("#watchdogPulse");
let watchdogStats = {};

watchdogToggle.addEventListener("change", async () => {
  const enabled = watchdogToggle.checked;
  watchdogPulse.classList.toggle("off", !enabled);
  try {
    await fetch(apiUrl("/api/teamwork/watchdog"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ enabled })
    });
  } catch { /* ignore */ }
});

// ─── Telegram alerts toggle ──────────────────────────────────────────

const telegramToggle = document.querySelector("#telegramToggle");
const telegramPulse = document.querySelector("#telegramPulse");

telegramToggle.addEventListener("change", async () => {
  const enabled = telegramToggle.checked;
  telegramPulse.classList.toggle("off", !enabled);
  try {
    await fetch(apiUrl("/api/teamwork/telegram"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ enabled })
    });
  } catch { /* ignore */ }
});

async function loadTelegramState() {
  try {
    const res = await fetch(apiUrl("/api/teamwork/telegram"), { cache: "no-store" });
    const data = await res.json();
    if (data.ok) {
      telegramToggle.checked = data.enabled;
      telegramPulse.classList.toggle("off", !data.enabled);
    }
  } catch { /* ignore */ }
}

async function loadWatchdogStats() {
  try {
    const res = await fetch(apiUrl("/api/teamwork/watchdog"), { cache: "no-store" });
    const data = await res.json();
    if (data.ok) {
      watchdogToggle.checked = data.enabled;
      watchdogPulse.classList.toggle("off", !data.enabled);
      watchdogStats = data.perMachine || {};
      updateWatchdogBadges();
    }
  } catch { /* ignore */ }
}

let alertDismissed = false;
let alertDismissedAt = 0;

function updateWatchdogBadges() {
  document.querySelectorAll(".tw-auto-badge").forEach((badge) => {
    const machineId = badge.dataset.watchdogMachine;
    const stats = watchdogStats[machineId];
    if (stats) {
      const total = (stats.claudeCount || 0) + (stats.codexCount || 0);
      if (total > 0) {
        badge.textContent = `🤖 ${total}`;
        badge.title = `Claude: ${stats.claudeCount || 0} | Codex: ${stats.codexCount || 0}`;
        badge.classList.add("has-approvals");
      } else {
        badge.textContent = "🤖 0";
        badge.title = "Sin auto-aprobaciones";
        badge.classList.remove("has-approvals");
      }
    }
  });
  checkPendingApprovals();
}

function checkPendingApprovals() {
  // Don't show if dismissed less than 30s ago
  if (alertDismissed && Date.now() - alertDismissedAt < 30000) return;

  const pendingClaude = [];
  const pendingCodex = [];

  for (const [machineId, stats] of Object.entries(watchdogStats)) {
    if (!stats) continue;
    // Check if Claude has approval buttons detected
    if (stats.claudeButtons && stats.claudeButtons.length > 0) {
      const machine = machines.find((m) => m.id === machineId);
      if (machine) pendingClaude.push(machine.name || machineId);
    }
    // Check claudeState for terminal pending
    if (stats.claudeState && stats.claudeState.includes("PENDING")) {
      const machine = machines.find((m) => m.id === machineId);
      if (machine && !pendingClaude.includes(machine.name || machineId)) pendingClaude.push(machine.name || machineId);
    }
    // Check codexState for pending
    if (stats.codexState && stats.codexState.includes("PENDING")) {
      const machine = machines.find((m) => m.id === machineId);
      if (machine) pendingCodex.push(machine.name || machineId);
    }
  }

  const alert = document.getElementById("approvalAlert");
  const backdrop = document.getElementById("approvalBackdrop");
  const machineList = document.getElementById("approvalMachineList");

  if (pendingClaude.length === 0 && pendingCodex.length === 0) {
    alert.classList.remove("visible");
    backdrop.classList.remove("visible");
    alertDismissed = false;
    return;
  }

  let html = "";
  for (const name of pendingClaude) {
    html += `<span class="tw-alert-machine-item"><span class="claude-tag">C</span> ${name}</span>`;
  }
  for (const name of pendingCodex) {
    html += `<span class="tw-alert-machine-item"><span class="codex-tag">X</span> ${name}</span>`;
  }
  machineList.innerHTML = html;

  // Show/hide specific approve buttons
  document.getElementById("alertApproveClaude").style.display = pendingClaude.length ? "" : "none";
  document.getElementById("alertApproveCodex").style.display = pendingCodex.length ? "" : "none";

  alert.classList.add("visible");
  backdrop.classList.add("visible");
}

window.dismissApprovalAlert = function() {
  document.getElementById("approvalAlert").classList.remove("visible");
  document.getElementById("approvalBackdrop").classList.remove("visible");
  alertDismissed = true;
  alertDismissedAt = Date.now();
};

window.alertApprove = async function(target) {
  const btn = document.getElementById(target === "claude" ? "alertApproveClaude" : "alertApproveCodex");
  btn.textContent = "...";
  btn.disabled = true;
  try {
    await fetch(apiUrl("/api/teamwork/approve"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ target, onlyPending: true })
    });
  } catch { /* ignore */ }
  btn.disabled = false;
  btn.textContent = target === "claude" ? "Claude" : "Codex";
  dismissApprovalAlert();
  setTimeout(loadSnapshots, 4000);
  setTimeout(loadWatchdogStats, 5000);
};

// ─── Init ──────────────────────────────────────────────────────────

// ─── Telegram Inbox: receive tasks from Telegram group ───────────────

const tgInbox = document.querySelector("#tgInbox");

async function loadTelegramInbox() {
  if (isStaticMode) return;
  try {
    const res = await fetch(apiUrl("/api/teamwork/telegram-inbox"), { cache: "no-store" });
    const data = await res.json();
    if (!data.ok || !data.messages?.length) {
      tgInbox.style.display = "none";
      tgInbox.innerHTML = "";
      return;
    }
    tgInbox.style.display = "flex";
    tgInbox.innerHTML = data.messages.map((msg, i) => `
      <div class="tw-tg-msg" title="Clic en Usar para cargar como prompt">
        <span class="tw-tg-icon">📱</span>
        <div class="tw-tg-body">
          <div class="tw-tg-from">${msg.from} via Telegram <span style="font-size:10px;padding:1px 5px;border-radius:4px;color:white;background:${msg.target === "claude" ? "#d63031" : "#0984e3"}">${msg.target === "claude" ? "Claude" : "Codex"}</span></div>
          <div class="tw-tg-text">${msg.text || "(imagen)"}</div>
          <div class="tw-tg-time">${timeAgo(msg.date)}</div>
        </div>
        ${msg.image ? `<img class="tw-tg-thumb" src="${msg.image}" alt="Imagen">` : ""}
        <div class="tw-tg-actions">
          <button class="tw-tg-use" onclick="event.stopPropagation(); useTgMessage(${i}, ${JSON.stringify(msg.text || "").replace(/"/g, '&quot;')}, '${msg.target || "codex"}')">${msg.target === "claude" ? "→ Claude" : "→ Codex"}</button>
          <button class="tw-tg-dismiss" onclick="event.stopPropagation(); dismissTgMessage(${i})">✕</button>
        </div>
      </div>
    `).join("");
    // Always load last message into prompt field + pre-select target
    const last = data.messages[data.messages.length - 1];
    const input = document.querySelector("#quickInput");
    const targetSelect = document.querySelector("#sendAllTarget");
    if (last?.text && input) {
      input.value = last.text;
      const targetLabel = last.target === "claude" ? "Claude" : "Codex";
      input.placeholder = `📱 ${last.from} → ${targetLabel}: listo para enviar`;
      if (targetSelect) targetSelect.value = last.target || "codex";
    }
  } catch { /* ignore */ }
}

window.useTgMessage = function(index, text, target) {
  const input = document.querySelector("#quickInput");
  const targetSelect = document.querySelector("#sendAllTarget");
  if (input && text) {
    input.value = text;
    if (targetSelect && target) targetSelect.value = target;
    input.focus();
  }
};

window.dismissTgMessage = async function(index) {
  try {
    await fetch(apiUrl("/api/teamwork/telegram-inbox/dismiss"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ index })
    });
    loadTelegramInbox();
  } catch { /* ignore */ }
};

// ─── Init ──────────────────────────────────────────────────────────

loadMachines();
loadHistory();
setTimeout(loadSnapshots, 2000);
setTimeout(loadWatchdogStats, 3000);
setTimeout(loadTelegramState, 3500);
setTimeout(loadTelegramInbox, 4000);
setInterval(loadHistory, 10_000);
setInterval(loadSnapshots, 30_000);
setInterval(loadWatchdogStats, 15_000);
// Refresh Tailscale status every 60s (synced with server healthCheck)
setInterval(async () => { await loadTailscaleStatus(); renderMachineApproveList(null); }, 60_000);
// Poll Telegram inbox every 10s
setInterval(loadTelegramInbox, 10_000);
