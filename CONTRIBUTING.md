# Cómo contribuir

## Preparar un cambio

1. Revisar README, políticas y estado de Git; preservar trabajo ajeno.
2. Crear una rama específica desde la referencia main revisada. No mezclar
   implementación, infraestructura y documentación sin una razón concreta.
3. Registrar qué cambia, por qué y cómo comprobarlo.
4. Añadir al commit solo las rutas revisadas y comprobar el diff.
5. Publicar por PR cuando el propietario lo autorice, con título y descripción
   en español y evidencia correspondiente al commit actual.

Conservar la autoría humana configurada. No añadir atribuciones de herramientas
en commits o PR. No usar push forzado ni reescribir historial publicado.

## Validación

Para Markdown, comprobar enlaces locales, conflictos y formato del diff.
No ejecutar operaciones de Terraform ni acceder a AWS/Atlas para validar documentos.
Si cambia infraestructura, seguir los controles del README y registrar el plan,
el entorno y sus efectos. Un análisis estático no autoriza un apply.

No declarar CI verde antes de comprobar los checks del SHA revisado.
Distinguir validación local, CI, fusión y aplicación del plan.

## Reportes y conducta

Los errores reproducibles y mejoras se registran en [Issues](https://github.com/al140605/barberterraform/issues).
Buscar duplicados e incluir entorno, resultado esperado y criterio de aceptación.
No publicar vulnerabilidades ni secretos: usar [SECURITY](SECURITY.md).
Respetar el [código de conducta](CODE_OF_CONDUCT.md) y su contacto privado.

## Licencia de las contribuciones

El proyecto adopta [GPL-3.0-only](LICENSE). Debes tener derecho a aportar el material
bajo esa licencia. Conservar los avisos de terceros e identificar las condiciones
de cualquier componente externo. No se exige cesión de autoría.
Consulta [LICENSING](LICENSING.md).

La licencia no otorga acceso a cuentas, credenciales, datos o servicios externos,
ni autoriza aplicar cambios de infraestructura.
