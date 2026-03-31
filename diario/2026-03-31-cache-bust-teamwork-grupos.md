# 2026-03-31 · Cache bust de teamwork para grupos Consejo/Equipo

AdmiraNext Team

## Trabajo realizado

- Detectado fallo real de cache en `teamwork.js`.
- La logica nueva de separacion entre `Consejo de Administracion` y `Equipo` estaba bien, pero la URL seguia cargando `teamwork.js?v=20260331-5`.
- Actualizado el cache bust a `20260331-6` en:
  - `teamwork.html`
  - `control.html`
- Subida la version visible a `v2.3.5`.
- Subida la version del paquete a `0.3.5`.
