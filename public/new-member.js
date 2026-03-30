const STORAGE_KEY = "admira-next-new-member-draft-v1";
const MACHINES_CACHE_BUST = "20260330-1";
const DEFAULT_FOCUS = "Onboarding y puesta a punto del equipo";
const DEFAULT_LOCATION = "Madrid";
const DEFAULT_MACHINE_ROLE = "Equipo principal";

const form = document.querySelector("#intakeForm");
const feedbackNode = document.querySelector("#feedback");
const submitButton = document.querySelector("#submitButton");
const downloadButton = document.querySelector("#downloadButton");
const copyButton = document.querySelector("#copyButton");
const resetButton = document.querySelector("#resetButton");
const modeBadge = document.querySelector("#modeBadge");
const modeHint = document.querySelector("#modeHint");
const tailnetHint = document.querySelector("#tailnetHint");
const previewMode = document.querySelector("#previewMode");
const previewChecklist = document.querySelector("#previewChecklist");
const jsonPreview = document.querySelector("#jsonPreview");

const previewNodes = {
  name: document.querySelector("#previewName"),
  member: document.querySelector("#previewMember"),
  status: document.querySelector("#previewStatus"),
  id: document.querySelector("#previewId"),
  host: document.querySelector("#previewHost"),
  ssh: document.querySelector("#previewSsh"),
  location: document.querySelector("#previewLocation"),
  role: document.querySelector("#previewRole"),
  machineRole: document.querySelector("#previewMachineRole"),
  focus: document.querySelector("#previewFocus")
};

const defaultDraft = {
  member: "",
  role: "",
  teamArea: "",
  location: DEFAULT_LOCATION,
  machineName: "",
  machineRole: DEFAULT_MACHINE_ROLE,
  platform: "macOS",
  color: "plata",
  status: "maintenance",
  currentFocus: DEFAULT_FOCUS,
  hostAlias: "",
  tailscaleIp: "",
  sshUser: "csilvasantin",
  remoteReady: "no",
  tailscaleReady: false,
  sshReady: false,
  githubReady: false,
  claudeBotReady: false,
  codexBotReady: false,
  needsHelp: "",
  note: ""
};

const context = {
  isStaticMode: true,
  tailnet: "",
  machines: []
};
const params = new URLSearchParams(window.location.search);
const intakePresets = {
  "creative-macbook-air-clean": {
    teamArea: "Consejo creativo",
    role: "Creatividad y experiencia",
    machineName: "MacBook Air creativo",
    machineRole: "Equipo creativo",
    platform: "macOS",
    color: "plata",
    status: "maintenance",
    currentFocus: "Primer arranque del MacBook Air creativo",
    remoteReady: "no",
    tailscaleReady: false,
    sshReady: false,
    githubReady: false,
    claudeBotReady: false,
    codexBotReady: false,
    needsHelp: "Equipo nuevo sin instalar. Pendiente de Tailscale, GitHub, ClaudeBot y CodexBot."
  }
};

function normalizeToken(value) {
  return String(value || "")
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function cleanString(value, fallback = "") {
  const trimmed = String(value || "").trim();
  return trimmed || fallback;
}

function readDraftFromStorage() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return applyPreset({ ...defaultDraft });
    }

    return applyPreset({ ...defaultDraft, ...JSON.parse(raw) });
  } catch {
    return applyPreset({ ...defaultDraft });
  }
}

function applyPreset(draft) {
  const presetName = params.get("preset");
  if (!presetName || !intakePresets[presetName]) {
    return draft;
  }

  return {
    ...draft,
    ...intakePresets[presetName],
    member: draft.member || "",
    hostAlias: draft.hostAlias || "",
    tailscaleIp: draft.tailscaleIp || "",
    note: draft.note || ""
  };
}

function writeDraftToStorage(draft) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(draft));
}

function fillForm(draft) {
  for (const [key, value] of Object.entries(draft)) {
    const element = form.elements.namedItem(key);
    if (!element) {
      continue;
    }

    if (element instanceof RadioNodeList) {
      continue;
    }

    if (element.type === "checkbox") {
      element.checked = Boolean(value);
    } else {
      element.value = value;
    }
  }
}

function readDraftFromForm() {
  const formData = new FormData(form);
  return {
    member: cleanString(formData.get("member")),
    role: cleanString(formData.get("role")),
    teamArea: cleanString(formData.get("teamArea")),
    location: cleanString(formData.get("location"), DEFAULT_LOCATION),
    machineName: cleanString(formData.get("machineName")),
    machineRole: cleanString(formData.get("machineRole"), DEFAULT_MACHINE_ROLE),
    platform: cleanString(formData.get("platform"), "macOS"),
    color: cleanString(formData.get("color"), "plata"),
    status: cleanString(formData.get("status"), "maintenance"),
    currentFocus: cleanString(formData.get("currentFocus"), DEFAULT_FOCUS),
    hostAlias: cleanString(formData.get("hostAlias")),
    tailscaleIp: cleanString(formData.get("tailscaleIp")),
    sshUser: cleanString(formData.get("sshUser"), "csilvasantin"),
    remoteReady: cleanString(formData.get("remoteReady"), "no"),
    tailscaleReady: formData.get("tailscaleReady") === "on",
    sshReady: formData.get("sshReady") === "on",
    githubReady: formData.get("githubReady") === "on",
    claudeBotReady: formData.get("claudeBotReady") === "on",
    codexBotReady: formData.get("codexBotReady") === "on",
    needsHelp: cleanString(formData.get("needsHelp")),
    note: cleanString(formData.get("note"))
  };
}

function buildChecklist(draft) {
  return {
    tailscaleReady: draft.tailscaleReady,
    sshReady: draft.sshReady,
    githubReady: draft.githubReady,
    claudeBotReady: draft.claudeBotReady,
    codexBotReady: draft.codexBotReady,
    needsHelp: draft.needsHelp
  };
}

function buildChecklistSummary(checklist) {
  return [
    checklist.tailscaleReady ? "Tailscale listo" : "Tailscale pendiente",
    checklist.sshReady ? "SSH listo" : "SSH pendiente",
    checklist.githubReady ? "GitHub listo" : "GitHub pendiente",
    checklist.claudeBotReady ? "ClaudeBot listo" : "ClaudeBot pendiente",
    checklist.codexBotReady ? "CodexBot listo" : "CodexBot pendiente"
  ].join(" | ");
}

function buildUniqueId(baseId) {
  const takenIds = new Set(context.machines.map((machine) => machine.id));
  let candidate = baseId;
  let suffix = 2;

  while (takenIds.has(candidate)) {
    candidate = `${baseId}-${suffix}`;
    suffix += 1;
  }

  return candidate;
}

function buildDerivedRecord(draft) {
  const checklist = buildChecklist(draft);
  const checklistSummary = buildChecklistSummary(checklist);
  const hostAlias = normalizeToken(draft.hostAlias);
  const fullHost = hostAlias ? (context.tailnet ? `${hostAlias}.${context.tailnet}` : hostAlias) : "";
  const sshEnabled = draft.remoteReady === "yes";
  const sshUser = cleanString(draft.sshUser, "csilvasantin");
  const connectTailscale = sshEnabled
    ? (draft.tailscaleIp
        ? `ssh ${sshUser}@${draft.tailscaleIp}`
        : hostAlias
          ? `ssh -o ProxyCommand='tailscale nc %h %p' ${sshUser}@${hostAlias}`
          : "")
    : "";
  const rawBaseId = normalizeToken(hostAlias || draft.machineName || draft.member || "equipo");
  const baseId = rawBaseId.startsWith("admira-") ? rawBaseId : `admira-${rawBaseId}`;
  const id = buildUniqueId(baseId);
  const note = draft.note || (draft.needsHelp
    ? `Alta autoservicio. ${checklistSummary}. Ayuda solicitada: ${draft.needsHelp}`
    : `Alta autoservicio. ${checklistSummary}.`);
  const now = new Date().toISOString();
  const payload = {
    member: draft.member,
    role: draft.role,
    teamArea: draft.teamArea,
    location: draft.location || DEFAULT_LOCATION,
    machineName: draft.machineName,
    machineRole: draft.machineRole || DEFAULT_MACHINE_ROLE,
    platform: draft.platform,
    color: draft.color,
    status: draft.status,
    currentFocus: draft.currentFocus || DEFAULT_FOCUS,
    note,
    hostAlias,
    tailscaleIp: draft.tailscaleIp,
    sshUser,
    remoteReady: sshEnabled,
    onboarding: checklist
  };
  const machineRecord = {
    id,
    color: payload.color,
    member: payload.member,
    role: payload.role,
    name: payload.machineName,
    machineRole: payload.machineRole,
    location: payload.location,
    platform: payload.platform,
    status: payload.status,
    lastSeen: now,
    currentFocus: payload.currentFocus,
    note: payload.note,
    ssh: {
      enabled: payload.remoteReady,
      user: payload.sshUser,
      host: fullHost,
      ip_tailscale: payload.tailscaleIp,
      connect_tailscale: connectTailscale,
      hostAlias
    },
    intake: {
      source: "new-member-form",
      submittedAt: now,
      teamArea: payload.teamArea,
      checklist
    }
  };

  return {
    payload,
    machineRecord,
    checklistSummary,
    fullHost,
    connectTailscale
  };
}

function renderMode() {
  const apiMode = !context.isStaticMode;
  modeBadge.textContent = apiMode ? "Modo panel editable" : "Modo Pages / exportacion";
  modeBadge.className = `mode-pill ${apiMode ? "api" : "static"}`;
  modeHint.textContent = apiMode
    ? "Al enviar, la ficha se registrara directamente en AdmiraNext Team."
    : "La version publica no puede escribir en el panel. Puedes descargar el JSON y compartirlo con el equipo.";
  submitButton.textContent = apiMode ? "Registrar alta" : "Preparar y descargar ficha";
  previewMode.textContent = apiMode ? "guardado directo disponible" : "exportacion manual";
  previewMode.className = `mini-pill ${apiMode ? "ok" : "warn"}`;
}

function renderPreview() {
  const draft = readDraftFromForm();
  writeDraftToStorage(draft);
  const derived = buildDerivedRecord(draft);

  previewNodes.name.textContent = draft.machineName || "Equipo pendiente";
  previewNodes.member.textContent = draft.member ? `${draft.member}${draft.teamArea ? ` · ${draft.teamArea}` : ""}` : "Sin miembro definido";
  previewNodes.status.textContent = draft.status || "maintenance";
  previewNodes.status.className = `preview-status ${draft.status || "maintenance"}`;
  previewNodes.id.textContent = derived.machineRecord.id;
  previewNodes.host.textContent = derived.fullHost || "Pendiente";
  previewNodes.ssh.textContent = derived.connectTailscale || "Pendiente";
  previewNodes.location.textContent = draft.location || DEFAULT_LOCATION;
  previewNodes.role.textContent = draft.role || "Sin rol definido";
  previewNodes.machineRole.textContent = draft.machineRole || DEFAULT_MACHINE_ROLE;
  previewNodes.focus.textContent = draft.currentFocus || DEFAULT_FOCUS;
  previewChecklist.textContent = derived.checklistSummary;
  jsonPreview.textContent = JSON.stringify(derived.machineRecord, null, 2);
  tailnetHint.textContent = context.tailnet
    ? `Si lo indicas, se convertira en ${cleanString(draft.hostAlias) ? `${normalizeToken(draft.hostAlias)}.${context.tailnet}` : `<alias>.${context.tailnet}`}.`
    : "Si lo indicas, se convertira en tu host completo.";
}

function showFeedback(message, kind) {
  feedbackNode.textContent = message;
  feedbackNode.className = `intake-feedback ${kind}`;
}

function clearFeedback() {
  feedbackNode.textContent = "";
  feedbackNode.className = "intake-feedback";
}

function validateDraft(draft) {
  const missing = [];

  if (!draft.member) {
    missing.push("nombre visible");
  }

  if (!draft.role) {
    missing.push("rol");
  }

  if (!draft.machineName) {
    missing.push("nombre visible de la maquina");
  }

  return missing;
}

function downloadJson(filename, content) {
  const blob = new Blob([content], { type: "application/json;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

async function copySummaryToClipboard() {
  const draft = readDraftFromForm();
  const derived = buildDerivedRecord(draft);
  const summary = [
    "Alta nueva AdmiraNext",
    `Miembro: ${derived.machineRecord.member || "-"}`,
    `Rol: ${derived.machineRecord.role || "-"}`,
    `Area: ${derived.machineRecord.intake.teamArea || "-"}`,
    `Maquina: ${derived.machineRecord.name || "-"}`,
    `ID sugerido: ${derived.machineRecord.id}`,
    `Estado inicial: ${derived.machineRecord.status}`,
    `Host Tailscale: ${derived.fullHost || "-"}`,
    `SSH: ${derived.connectTailscale || "pendiente"}`,
    `Foco actual: ${derived.machineRecord.currentFocus}`,
    `Checklist: ${derived.checklistSummary}`,
    `Nota: ${derived.machineRecord.note}`
  ].join("\n");

  await navigator.clipboard.writeText(summary);
  showFeedback("Resumen copiado. Ya puedes pegarlo en chat o compartirlo con el equipo.", "ok");
}

async function loadContext() {
  try {
    const response = await fetch("/api/machines", { cache: "no-store" });
    if (!response.ok) {
      throw new Error("api unavailable");
    }

    const data = await response.json();
    context.isStaticMode = false;
    context.tailnet = data.tailnet || "";
    context.machines = data.machines || [];
  } catch {
    const response = await fetch(`./machines.json?v=${MACHINES_CACHE_BUST}`, { cache: "no-store" });
    const data = await response.json();
    context.isStaticMode = true;
    context.tailnet = data.tailnet || "";
    context.machines = data.machines || [];
  }
}

async function submitDraft(event) {
  event.preventDefault();
  clearFeedback();

  const draft = readDraftFromForm();
  const missing = validateDraft(draft);
  if (missing.length) {
    showFeedback(`Faltan campos obligatorios: ${missing.join(", ")}.`, "err");
    return;
  }

  const derived = buildDerivedRecord(draft);

  if (context.isStaticMode) {
    downloadJson(`alta-${derived.machineRecord.id}.json`, `${JSON.stringify(derived.machineRecord, null, 2)}\n`);
    showFeedback("La ficha se ha descargado en JSON. Compartela con el equipo para importarla en el panel editable.", "ok");
    return;
  }

  submitButton.disabled = true;
  submitButton.textContent = "Registrando...";

  try {
    const response = await fetch("/api/machines", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(derived.payload)
    });
    const result = await response.json().catch(() => ({}));

    if (!response.ok) {
      throw new Error(result.error || "No se pudo registrar la ficha");
    }

    context.machines.push(result.machine);
    localStorage.removeItem(STORAGE_KEY);
    fillForm({ ...defaultDraft });
    renderPreview();
    showFeedback(`Alta completada. La nueva ficha ya existe en el panel con el ID ${result.machine.id}.`, "ok");
  } catch (error) {
    showFeedback(error instanceof Error ? error.message : "No se pudo registrar la ficha", "err");
  } finally {
    submitButton.disabled = false;
    renderMode();
  }
}

function resetDraft() {
  const confirmed = window.confirm("Esto borrara el borrador actual del formulario. ¿Seguimos?");
  if (!confirmed) {
    return;
  }

  localStorage.removeItem(STORAGE_KEY);
  fillForm({ ...defaultDraft });
  clearFeedback();
  renderPreview();
}

form.addEventListener("input", () => {
  clearFeedback();
  renderPreview();
});

form.addEventListener("change", () => {
  clearFeedback();
  renderPreview();
});

form.addEventListener("submit", submitDraft);

downloadButton.addEventListener("click", () => {
  const draft = readDraftFromForm();
  const missing = validateDraft(draft);
  if (missing.length) {
    showFeedback(`Antes de descargar, completa: ${missing.join(", ")}.`, "err");
    return;
  }

  const derived = buildDerivedRecord(draft);
  downloadJson(`alta-${derived.machineRecord.id}.json`, `${JSON.stringify(derived.machineRecord, null, 2)}\n`);
  showFeedback("Ficha descargada en JSON.", "ok");
});

copyButton.addEventListener("click", async () => {
  try {
    await copySummaryToClipboard();
  } catch {
    showFeedback("No pude copiar el resumen al portapapeles.", "err");
  }
});

resetButton.addEventListener("click", resetDraft);

async function init() {
  fillForm(readDraftFromStorage());
  await loadContext();
  renderMode();
  renderPreview();
}

init();
