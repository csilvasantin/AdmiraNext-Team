# Guía de Actualización — AdmiraNext

## Nomenclatura de versiones

**Formato obligatorio: vAA.DD.MM.N**

| Campo | Significado | Ejemplo |
|-------|------------|---------|
| AA | Año (últimos 2 dígitos) | 26 = 2026 |
| DD | Día del mes | 01-31 |
| MM | Mes del año | 01-12 |
| N | Secuencial del día | 1, 2, 3... |

**Ejemplo:** `v26.11.04.3` = año 2026, día 11, abril, tercera versión del día.

## Reglas de versionado

1. **Cada push = incrementar N.** Sin excepciones.
2. **Nuevo día = reset N a 1.** Ejemplo: `v26.11.04.5` → al día siguiente → `v26.12.04.1`
3. **La versión debe ser visible** en el header de todas las páginas HTML.
4. **No usar otros formatos** (v1.0.0, semver, etc.). Solo `vAA.DD.MM.N`.

## Proceso de actualización

1. Hacer los cambios en el código
2. Buscar la versión actual en el HTML (ej: `v26.11.04.1`)
3. Incrementar N → `v26.11.04.2`
4. Actualizar la versión en TODOS los sitios donde aparezca (header, footer, title)
5. `git add` + `git commit` + `git push`
6. Enviar resumen a Telegram (bot Memorizer, grupo TecnologíaNext) firmado por "Admirito by [IA]"
7. Verificar en GitHub Pages que la versión nueva es visible

## Proyectos activos

| Proyecto | URL pública | Repo |
|----------|------------|------|
| Council Dashboard | https://csilvasantin.github.io/admiranext.html | csilvasantin.github.io |
| Control Codex & Claude | https://csilvasantin.github.io/03-ControlCodexClaude/ | 03-ControlCodexClaude |

## Telegram — Memorizer

Cada cambio significativo se envía al grupo **TecnologíaNext** con:
- Nombre del proyecto y versión nueva
- Lista de cambios (bullet points)
- URL pública de GitHub Pages
- Firmado: _Enviado por Admirito by [IA]_ 🤖
