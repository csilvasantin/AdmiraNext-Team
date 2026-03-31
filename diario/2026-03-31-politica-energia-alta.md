# Diario - 2026-03-31

## Proyecto

AdmiraNext Team

## Trabajo realizado

- Se ha integrado la politica de energia base del DreamTeam en el flujo de alta: hasta `4` horas enchufado y `1` hora en bateria.
- Se ha añadido tambien una politica de actualizaciones del sistema: comprobacion automatica, descarga e instalacion automatica de parches menores y de seguridad.
- Los upgrades grandes de macOS quedan explicitamente fuera del modo automatico y pasan a validacion manual previa.
- Se ha marcado la `Grabacion de pantalla` como requisito obligatorio en todos los equipos de `AdmiraNext`, no como permiso opcional de ultima hora.
- La regla queda documentada en `welcomePack` y reflejada tambien en `onboarding`.
- El `bootstrap .command` de alta aplica automaticamente `sudo pmset -c sleep 240`, `sudo pmset -b sleep 60`, deja activadas las autoactualizaciones menores y de seguridad y recuerda al final la `Grabacion de pantalla` como must.

## Estado actual

- La politica base del sistema ya no depende de memoria informal ni de pasos manuales fuera del flujo de alta.
- La capacidad de capturar pantalla para supervision o relevo queda reflejada como requisito operativo comun.
- El formulario de `AdmiraNext-Team` y su bootstrap muestran la misma regla para mantener coherencia entre documentacion y ejecucion.
