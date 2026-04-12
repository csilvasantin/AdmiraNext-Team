# Proyecto 03 — AdmiraNext Team

> Panel ligero para controlar el estado de los miembros del equipo, centrado en sus ordenadores.

## Contexto

Sistema de gestión de equipos y máquinas con panel web en tiempo real. Incluye:
- Alta autoservicio para nuevos fichajes (new-member.html)
- Panel operativo con 5 estados de máquina (online, idle, busy, offline, maintenance)
- Servidor Node sin dependencias externas con API JSON local
- Almacenamiento en `data/machines.json`
- Integración con Telegram bots para 8 perfiles del Consejo de Administración

URLs públicas:
- Local: `http://127.0.0.1:3030`
- CEO: `http://127.0.0.1:3030/alta` o `/ceo`
- Creativa: `http://127.0.0.1:3030/alta-creativa`
- Publica (GitHub Pages): `https://csilvasantin.github.io/AdmiraNext-Team/new-member.html`

## Arquitectura

```
AdmiraNext-Team/
├── npm start → puerto 3030
├── data/
│   └── machines.json         # Persistencia de máquinas y personas
├── consejeros/               # 8 perfiles (CEO, CFO, COO, CTO, CCO, CSO, CXO, CDO)
│   └── README.md             # Detalles de bots Telegram
├── new-member.html           # Alta autoservicio
├── control.html              # Panel de control GUI (si Mac con screencapture)
└── API endpoints
    ├── GET /api/machines
    ├── POST /api/teamwork/onboarding-all
    └── POST /api/machines/:id/sync
```

## Notas para IAs

1. **Nodo GUI en macOS**: Usar `npm run agent:doctor` y `npm run agent:install` para instalar como LaunchAgent dentro de sesión Aqua. Requiere permisos de Accesibilidad y Grabación de Pantalla.

2. **Onboarding**: `onboarding-all` es una acción coordinada — hace onboarding local primero en la IA coordinadora, luego reenvía canónico a todos. Prioridad de canales: Codex > Claude > Terminal.

3. **Consejo de Administración**: 4 parejas coetáneas (lado operativo vs creativo). Los bots están en `csilvasantin/Yarig.Telegram` (src/consejero_bot.py + src/consejeros_runner.py).

4. **Próximos pasos**: Completar 3 bots pendientes, crear grupo Telegram, avatares, API key Anthropic, login web, separar entidades (miembros, equipos, tareas), integrar agentes por máquina.

5. **Sync de estado**: POST a `/api/machines/:id/sync` con campos: status, currentFocus, note.

## Screen Agent — Capturas remotas

Cada Mac del consejo ejecuta un screen-agent que captura pantalla y la envía al servidor cada 30s.

### Arquitectura

```
Mac remoto (council)
├── ~/.admiranext/screen-agent.sh     # Script de captura (estable, no /tmp)
├── ~/Library/LaunchAgents/com.admiranext.screen-agent.plist  # Sesión Aqua
└── /tmp/screen-agent.log             # Log de salida

Mac Mini (servidor)
├── ops/screen-agent.sh               # Fuente canónica del script
├── ops/deploy-screen-agents.sh       # Deploy a todas las council Macs
└── POST /api/screenshots/:id         # Endpoint que recibe los JPEGs
```

### Captura: Quartz primario, screencapture fallback

El screen-agent usa Python+Quartz (AppKit) como método primario porque:
- **No necesita permiso de Grabación de Pantalla** (a diferencia de `screencapture`)
- Funciona desde launchd Aqua sin configuración adicional
- Si Quartz falla, intenta `screencapture` como fallback

### Deploy

```bash
# Desde el Mac Mini — despliega a todas las council Macs online:
cd /Users/csilvasantin/AdmiraNext-Team
ops/deploy-screen-agents.sh

# Dry run (solo muestra qué haría):
ops/deploy-screen-agents.sh --dry-run
```

El script:
1. Copia `screen-agent.sh` a `~/.admiranext/` en cada Mac (ruta estable)
2. Genera e instala el LaunchAgent plist con machine-id correcto
3. Reinicia el agente via `launchctl`
4. Limpia copias viejas en /tmp
5. Salta máquinas offline sin fallar

### Pilares (Abrir/Cerrar apps remotamente)

Los 3 pilares (Telegram, Codex, Claude Code) se pueden abrir/cerrar desde el panel:
- **Botones globales**: "Abrir Todo" / "Cerrar Todo" en el header del Consejo (con confirmación)
- **Por máquina**: iconos T/X/C con botones Abrir/Cerrar directos
- **Iconos iluminados**: glow cuando la app está abierta, apagados si cerrada
- **Burst capture**: tras abrir/cerrar, captura cada 5s x6 para feedback rápido
- **API**: `POST /api/teamwork/pillar` y `/pillar-all`

### Troubleshooting

- **"Conectado — captura no disponible"**: Quartz y screencapture fallaron. Ejecutar `ops/deploy-screen-agents.sh` para reinstalar.
- **Screenshot no se actualiza**: Verificar que el screen-agent corre: `ssh <machine> 'pgrep -f screen-agent'`
- **Iconos apagados**: El watchdog tarda ~15s en el primer escaneo tras reinicio del servidor.

## Council Dashboard (Demo System)

### Visión general

El Council Dashboard muestra el estado en tiempo real de las 8 sillas del consejo (4 Racional + 4 Creativo), cada una mapeada a una máquina física. Vive en:

- **Dashboard**: `https://csilvasantin.github.io/admiranext.html`
- **Fallback estable**: `https://csilvasantin.github.io/admiranext-v2.html`
- **Código fuente**: repo `csilvasantin/csilvasantin.github.io` → `admiranext.html`

### Arquitectura del Demo Server

```
Mac Mini (servidor central)
├── ops/demo-server.py         # Puerto 3032, endpoints: /status, /screenshot/{id}, /ping, /power/{id}, /toggle/{id}
├── Tailscale Funnel           # HTTPS público: macmini.tail48b61c.ts.net
│   ├── /      → localhost:3030  (API principal AdmiraNext-Team)
│   └── /demo  → localhost:3032  (Demo server)
└── SSH a todos los Macs       # Clave: ~/.ssh/id_ed25519 (MacMini-MacMini.local)

PC Windows (AdmiraTwin)
└── screenshot-agent.py        # Puerto 3033, endpoints: /screenshot, /ping, /power
    └── Auto-start: Startup/screenshot-agent.vbs
```

### Mapeo Consejo → Máquinas

| Silla | Leyenda | Coetáneo | Máquina | ID | IP Tailscale |
|-------|---------|----------|---------|----|-------------|
| CEO | Steve Jobs | Elon Musk | MacBook Air 16 | admira-macbookair16 | 100.99.176.126 |
| CTO | Steve Wozniak | Jensen Huang | MacBook Pro Negro 14 | admira-macbookpronegro14 | 100.101.192.1 |
| COO | Tim Cook | Gwynne Shotwell | MacBook Air Plata | admira-macbookairplata | 100.114.113.88 |
| CFO | Warren Buffett | Ruth Porat | Mac Mini | admira-macmini | 100.74.101.14 |
| CCO | Walt Disney | John Lasseter | MacBook Air Blanco | admira-macbookairblanco | 100.75.118.75 |
| CDO | Dieter Rams | Jony Ive | MacBook Air Azul | admira-macbookairazul | 100.84.81.45 |
| CXO | Howard Schultz | Carlos Ratti | AdmiraTwin PC (Windows) | admira-pctwin | 100.121.18.12 |
| CSO | George Lucas | Ryan Reynolds | MacBook Air Crema | admira-macbookaircrema | 100.110.80.2 |

### Cómo funciona el botón DEMO

1. El dashboard hace `fetch(DEMO_PING)` a `https://macmini.tail48b61c.ts.net/demo/ping`
2. Si responde `pong`, activa modo Demo: polling cada 3s al demo server
3. El demo server consulta `tailscale status` para saber qué máquinas están online
4. Screenshots: SSH+Quartz para Macs, HTTP agent para Windows
5. Pantallas bloqueadas: detecta imágenes en blanco/negro y conserva la última captura buena
6. Thumbnails: grayscale+dim cuando offline, color+borde verde+hora cuando online
7. Overlay al click: "EN VIVO · HH:MM:SS" (verde) o "Ultima captura · fecha" (naranja)

### Power control (encendido/apagado)

- **Sleep Mac**: SSH → `pmset sleepnow`
- **Wake Mac**: Wake-on-LAN (magic packet a la MAC address)
- **Sleep PC Windows**: HTTP agent → PowerShell `SetSuspendState`
- En modo Demo, los comandos van por `https://macmini.tail48b61c.ts.net/demo/power/{id}`
- En modo normal, van por `https://macmini.tail48b61c.ts.net/api/machines/{id}/power`

### SSH keys

La clave pública del Mac Mini (`MacMini-MacMini.local`) debe estar en `~/.ssh/authorized_keys` de cada Mac para que las capturas de pantalla funcionen. Si añades una máquina nueva:

```bash
# Desde un PC que tenga acceso SSH al nuevo Mac:
ssh csilvasantin@<IP> "echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM4kZtaWgCQ/SrvznW9S3re5IDqwU4ZVgb+d4xAw5Fs1 MacMini-MacMini.local' >> ~/.ssh/authorized_keys"
```

Si el Mac tiene Tailscale SSH activo (intercepta conexiones), desactivarlo:
```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale set --ssh=false
```
Y activar "Inicio de sesión remoto" en Ajustes del Sistema > General > Compartir.

### Tailscale Funnel (Mac Mini)

Configuración actual:
```bash
# Ver estado
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status

# Resultado esperado:
# https://macmini.tail48b61c.ts.net/      → proxy http://127.0.0.1:3030
# https://macmini.tail48b61c.ts.net/demo  → proxy http://127.0.0.1:3032
# Funnel: ON
```

### Arrancar el sistema

```bash
# En el Mac Mini:
cd ~/Claude/repos/AdmiraNext-Team
nohup python3 ops/demo-server.py > /tmp/demo-server.log 2>&1 &

# En el PC Windows (auto en Startup, o manual):
pythonw C:\Users\34665\cLAUDE\screenshot-agent.py
```

### Notas Tailscale

- Algunos Macs tienen doble identidad (ej: `macbookairplata` y `macbookairplata-1`). El mapping en `TAILSCALE_TO_ID` del demo server cubre ambos.
- El hostname real del Mac puede no coincidir con el de Tailscale. Verificar con `tailscale status` desde el Mac Mini.
