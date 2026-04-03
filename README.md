# AdmiraNext Team

Panel ligero para controlar el estado de los miembros del equipo, centrado en sus ordenadores.

## Alta autoservicio

El repositorio incluye una pagina de alta para que un nuevo fichaje complete su propia ficha de persona, maquina y acceso sin depender de una carga manual inicial.

- Local con persistencia real: `http://127.0.0.1:3030/new-member.html`
- Publica con exportacion de ficha: `https://csilvasantin.github.io/AdmiraNext-Team/new-member.html`
- Entrada corta principal `CEO`: `http://127.0.0.1:3030/alta` y `http://127.0.0.1:3030/ceo`
- Entrada creativa: `http://127.0.0.1:3030/alta-creativa`

## Objetivo

Tener una vista simple y operativa de:

1. qué máquinas existen;
2. a qué miembro pertenecen;
3. cuál es el rol de cada persona y de cada equipo;
3. cuál es su estado actual;
4. en qué está trabajando cada uno ahora mismo;
5. cuándo fue la última actualización;
6. notas rápidas de operación.

## Estado actual

Este MVP incluye:

1. servidor Node sin dependencias externas;
2. API JSON local;
3. panel web para ver equipos y máquinas;
4. cambio rápido de estado desde la interfaz;
5. foco actual de trabajo por máquina;
6. almacenamiento en `data/machines.json`.

## Estados disponibles

1. `online`
2. `idle`
3. `busy`
4. `offline`
5. `maintenance`

## Arranque

```bash
cd /Users/Carlos/Documents/AdmiraNext-Team
npm start
```

Después abre:

```text
http://127.0.0.1:3030
```

## Nodo GUI en macOS

Si un Mac debe actuar como nodo de control con capturas reales, no conviene arrancarlo por SSH en segundo plano. En ese modo macOS suele negar `screencapture` y `System Events`, y el panel cae a texto tipo `sin sesion grafica`.

Ruta recomendada:

```bash
cd /Users/Carlos/Documents/AdmiraNext-Team
npm run agent:doctor
npm run agent:install
```

Que hace cada comando:

1. `npm run agent:doctor`
2. comprueba sesion GUI, AppleScript, captura de pantalla y API local;
3. avisa si faltan permisos de `Accesibilidad` o `Grabacion de pantalla`.

1. `npm run agent:install`
2. crea `~/Library/LaunchAgents/com.admiranext.control.plist`;
3. arranca el servidor como `LaunchAgent` dentro de la sesion `Aqua`;
4. deja logs en `~/Library/Logs/AdmiraNext/control-agent.out.log` y `control-agent.err.log`.

Para retirarlo:

```bash
npm run agent:uninstall
```

Validacion recomendada despues de instalar:

```text
http://127.0.0.1:3030/control.html
```

Si ese Mac publica el hub por Tailscale Funnel, valida tambien la URL publica con cache-buster.

## Arquitectura LAN de capturas

Desde abril de 2026 el flujo operativo recomendado en LAN queda asi:

1. el `Mac Mini` actua como hub central en `:3030`;
2. cada Mac remoto que deba publicar captura real corre su propio `LaunchAgent` GUI en `~/AdmiraNext-Control-Agent`;
3. el hub intenta leer primero `http://127.0.0.1:3030/api/teamwork/snapshots` dentro de cada Mac remoto;
4. si ese nodo GUI remoto responde, el hub reutiliza esa captura real de la sesion `Aqua`;
5. solo si el nodo GUI no responde, el hub cae al fallback SSH con `Quartz` o a texto.

Reglas importantes:

1. el modo multi-monitor fijo solo aplica al `Mac Mini` hub;
2. los portatiles locales o remotos publican una sola imagen de su pantalla real;
3. el panel no borra un preview bueno hasta tener otro visual nuevo;
4. cuando un equipo remoto tarda en responder, el hub reintenta rapido para no dejarlo oculto demasiado tiempo.

Rutas y piezas clave:

1. hub central: [src/ssh-exec.js](./src/ssh-exec.js)
2. instalador de nodo GUI: [ops/macos/install-launchagent.sh](./ops/macos/install-launchagent.sh)
3. doctor de permisos GUI: [ops/macos/doctor-gui-capture.sh](./ops/macos/doctor-gui-capture.sh)

## Watchdog y autoaprobaciones

El watchdog del panel intenta detectar y aprobar permisos pendientes sin depender de una sola app.

Fuentes que vigila:

1. `Claude Desktop` por botones nativos y botones dentro del webview;
2. `Codex` app por titulo de ventana y texto de la propia app;
3. `Claude Code` en `Terminal` o `iTerm2`;
4. `Codex CLI` en `Terminal` o `iTerm2`.

Acciones de autoaprobacion:

1. `Claude Desktop`: `Ctrl+Enter`
2. `Codex` app: `2` + `Enter`
3. `Claude Code` en terminal: activa el terminal correcto y envia `Ctrl+Enter`
4. `Codex CLI` en terminal: activa el terminal correcto y envia `2` + `Enter`

Notas operativas:

1. distinguir `Codex` app de `Codex CLI` es importante porque el gesto de aprobacion y la app destino no son los mismos;
2. el watchdog guarda contadores por maquina y el ultimo objetivo aprobado;
3. cada deteccion positiva dispara un sonido corto estilo Mario desde el hub central, con firma distinta para `Claude` y `Codex`;
4. si una maquina falla temporalmente, el sistema no la castiga durante minutos: reintenta en ciclos cortos para recuperar el control LAN enseguida.

Endpoint utiles:

```text
GET /api/teamwork/snapshots
GET /api/teamwork/watchdog
POST /api/teamwork/watchdog
POST /api/teamwork/watchdog/machine
```

## API local

### Listar máquinas

```text
GET /api/machines
```

### Lanzar onboarding global

```text
POST /api/teamwork/onboarding-all
Content-Type: application/json
{
  "prompt": "opcional, si se quiere sobrescribir el onboarding canónico"
}
```

Semantica operativa:

- `onboarding` es local y no debe emitirse a todos desde este panel;
- `onboarding all` hace primero el onboarding local en la IA coordinadora y despues reenvia el onboarding canonico a todos los equipos alcanzables;
- el backend intenta usar una sola via por maquina, con prioridad `Codex`, `Claude`, `Terminal`.

### Sincronizar estado y foco

```text
POST /api/machines/:id/sync
Content-Type: application/json
{
  "status": "busy",
  "currentFocus": "Instalando bots en equipo nuevo",
  "note": "Coordinando onboarding"
}
```

## Publicación web

La publicación pública funciona en modo solo lectura con GitHub Pages y carga `machines.json` directamente.

## Siguientes pasos recomendados

1. añadir login o clave simple;
2. separar miembros, equipos y tareas en entidades propias;
3. añadir comprobación real de salud de cada ordenador;
4. integrar bots o agentes por máquina;
5. guardar historial de estados y cambios de foco.
