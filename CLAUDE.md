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
