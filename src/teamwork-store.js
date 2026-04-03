const MAX_ENTRIES = 100;
const history = [];
let nextId = 1;

function createEntry({
  machineId,
  machineName,
  prompt,
  ok,
  error,
  captureId,
  target,
  action
}) {
  return {
    id: nextId++,
    machineId,
    machineName: machineName || machineId,
    prompt,
    action: action || "send",
    target: target || "terminal",
    sentAt: new Date().toISOString(),
    status: ok ? "sent" : "error",
    error: error || null,
    captureId: captureId || null
  };
}

function appendEntries(entries) {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    history.unshift(entries[index]);
  }

  if (history.length > MAX_ENTRIES) {
    history.length = MAX_ENTRIES;
  }
}

export function addEntry(machineId, machineName, prompt, ok, error, captureId, target) {
  const entry = createEntry({
    machineId,
    machineName,
    prompt,
    ok,
    error,
    captureId,
    target
  });
  appendEntries([entry]);

  return entry;
}

export function addEntries(items) {
  const entries = items.map((item) => createEntry(item));
  appendEntries(entries);
  return entries;
}

export function getHistory() {
  return history;
}
