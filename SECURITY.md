# Política de seguridad

Esta política cubre la configuración de infraestructura de UrbanBlade.
Los reportes de vulnerabilidades se comunican en privado, no en issues públicos.

## Reportar una vulnerabilidad

Utiliza el [canal privado del equipo UrbanBlade](https://github.com/KikeGonRam/barber/security/advisories/new)
e indica que el componente afectado es `barberterraform`.
Se utiliza este canal compartido sin asumir que el repositorio barberterraform
tenga habilitado su propio formulario privado.

Incluye el commit o versión afectada, entorno, impacto estimado, pasos mínimos con
datos ficticios y evidencia depurada. Si afecta a varios componentes, descríbelos
en un solo reporte. No publiques exploits, tokens o datos personales.

## Alcance de mantenimiento

Las correcciones se proponen por PR contra `main`.
Identifica el SHA evaluado: una rama local, un resultado de CI y una versión
aplicada a la infraestructura
son evidencias diferentes. No se promete un plazo de respuesta, una recompensa
o soporte por versión que el equipo no haya acordado.

El equipo revisará el reporte y coordinará la reproducción, mitigación y divulgación
por el canal privado. Un reporte no autoriza pruebas sobre producción, acceso a
cuentas ajenas, pagos reales, ingeniería social o modificaciones de datos.

## Estado, planes y credenciales de infraestructura

- No versionar ni compartir archivos de estado, backups de estado, planes binarios,
  terraform.tfvars, backend.hcl ni credenciales de AWS o Atlas.
- Un atributo sensitive puede ocultar un valor en pantalla sin eliminarlo del estado.
  Tratar estado y planes como material confidencial.
- No publicar exportaciones terraform show -json, salidas de consola o artefactos
  de CI sin depurarlos: pueden contener valores sensibles.
- Las credenciales proceden del entorno o del gestor autorizado, no de ejemplos,
  outputs o variables con valores reales en Git.
- Restringir el acceso al backend remoto y revisar cifrado, versionado y bloqueo
  en el entorno autorizado; la configuración versionada no prueba su aplicación.

## Cambios y pruebas

Una tarea documental no requiere terraform apply, destroy, import, migración de
estado o cambios de IAM. No ejecutarlos para verificar una política o una licencia.
Revisar la cuenta, workspace, backend, plan y efectos antes de una operación autorizada.
Un plan revisado para un entorno no se reutiliza ciegamente en otro.
Las herramientas de validación y análisis estático no sustituyen la revisión del
plan ni confirman el estado real de AWS/Atlas.

## Credenciales expuestas y dependencias

Comunica en privado ubicación y tipo, sin copiar el valor ni probar una credencial
ajena contra el proveedor. El responsable coordinará revocación o rotación y revisión
del uso. Eliminar el archivo actual no elimina su contenido del historial.
No reescribir Git, cambiar cuentas o desactivar controles de forma automática.

Los escáneres y resultados de CI son controles complementarios; no certifican
ausencia de vulnerabilidades. Los componentes de terceros conservan sus avisos y
licencias; los hallazgos se evalúan por alcance e impacto.

## Otras políticas

[Contribución](CONTRIBUTING.md) · [Código de conducta](CODE_OF_CONDUCT.md) ·
[Licencia](LICENSE) · [Alcance de la licencia](LICENSING.md).
